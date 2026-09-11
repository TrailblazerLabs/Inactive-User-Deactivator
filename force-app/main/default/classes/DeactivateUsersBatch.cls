/**
 * Batch + Scheduled job that deactivates Users according to per-profile rules
 * defined in Auto_User_Inactive__mdt. Each rule is either:
 *   - a fixed Deactivation_Date__c on the User that has passed, or
 *   - an inactivity window based on LastLoginDate (Number_of_Days__c).
 *
 * Implements Database.Stateful so results are accumulated across all chunks
 * and reported once in finish().
 */
public with sharing class DeactivateUsersBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    // Loaded once per job run (in start()), not once per chunk.
    private Map<String, Auto_User_Inactive__mdt> profileRulesByName;

    // Stateful accumulators for the finish() summary.
    private Integer totalEvaluated = 0;
    private Integer totalDeactivated = 0;
    private List<String> failures = new List<String>();

    // Never deactivate the account this job is running as.
    private static final Id RUNNING_USER_ID = UserInfo.getUserId();

    // ---- Test seams -------------------------------------------------------
    // Custom metadata can't be inserted via DML, and the "running user" is
    // fixed by the org context, so both are made overridable for tests only.
    // Neither is ever touched in production code paths.
    @TestVisible
    private static Map<String, Auto_User_Inactive__mdt> mockRules;
    @TestVisible
    private static Id mockRunningUserId;
    // -------------------------------------------------------------------

    public Database.QueryLocator start(Database.BatchableContext bc) {
        profileRulesByName = loadRules();

        // Filter in SOQL to only the profiles that have a rule configured,
        // instead of scanning every active user in the org.
        Set<String> profileNames = profileRulesByName.keySet();

        String query =
            'SELECT Id, Deactivation_Date__c, IsActive, Profile.Name, LastLoginDate ' +
            'FROM User ' +
            'WHERE IsActive = true AND Profile.Name IN :profileNames';

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        if (!Schema.sObjectType.User.fields.IsActive.isUpdateable()) {
            failures.add('Running user lacks FLS access to update User.IsActive; chunk skipped.');
            return;
        }

        Id runningUserId = (System.Test.isRunningTest() && mockRunningUserId != null)
            ? mockRunningUserId
            : RUNNING_USER_ID;

        List<User> usersToDeactivate = new List<User>();

        for (sObject s : scope) {
            User userRecord = (User) s;
            totalEvaluated++;

            if (userRecord.Id == runningUserId) {
                continue; // safety: don't deactivate the running/integration user
            }

            Auto_User_Inactive__mdt rule = profileRulesByName.get(userRecord.Profile.Name);
            if (rule == null) {
                continue;
            }

            if (shouldDeactivate(userRecord.Deactivation_Date__c, userRecord.LastLoginDate, rule)) {
                userRecord.IsActive = false;
                usersToDeactivate.add(userRecord);
            }
        }

        if (usersToDeactivate.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.update(usersToDeactivate, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                totalDeactivated++;
            } else {
                failures.add(usersToDeactivate[i].Id + ': ' + results[i].getErrors()[0].getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        sendSummaryEmail();
    }

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new DeactivateUsersBatch(), 200);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    private Map<String, Auto_User_Inactive__mdt> loadRules() {
        if (System.Test.isRunningTest() && mockRules != null) {
            return mockRules;
        }

        Map<String, Auto_User_Inactive__mdt> rules = new Map<String, Auto_User_Inactive__mdt>();
        for (Auto_User_Inactive__mdt rule : [
            SELECT Label, Number_of_Days__c, From_Last_Login_Date__c
            FROM Auto_User_Inactive__mdt
        ]) {
            rules.put(rule.Label, rule);
        }
        return rules;
    }

    // Takes the two relevant values as primitives, rather than a User
    // sObject, specifically so tests can exercise every branch — including
    // LastLoginDate scenarios — without touching that field's read-only
    // write restriction. Reading these off a real queried User at the call
    // site above is unaffected; only writes to LastLoginDate are blocked.
    @TestVisible
    private Boolean shouldDeactivate(Date deactivationDate, Datetime lastLoginDate, Auto_User_Inactive__mdt rule) {
        if (!rule.From_Last_Login_Date__c) {
            return deactivationDate != null && deactivationDate < Date.today();
        }

        // Normalize sign so the rule works regardless of how the admin entered it.
        Integer inactivityDays = rule.Number_of_Days__c != null
            ? Math.abs(rule.Number_of_Days__c.intValue())
            : 0;
        Datetime cutoff = Datetime.now().addDays(-inactivityDays);

        return lastLoginDate == null || lastLoginDate < cutoff;
    }

    private void sendSummaryEmail() {
        // TODO: replace with a real notification list (custom setting/label/queue).
        String recipient = System.Label.User_Deactivation_Notification_List;
        if (String.isBlank(recipient)) {
            return;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { recipient });
        mail.setSubject('User Deactivation Batch — Summary');

        String body = 'Evaluated: ' + totalEvaluated + '\n' +
                      'Deactivated: ' + totalDeactivated + '\n' +
                      'Failures: ' + failures.size();
        if (!failures.isEmpty()) {
            body += '\n\n' + String.join(failures, '\n');
        }
        mail.setPlainTextBody(body);

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}
