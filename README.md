
# Automatic Deactivation of Inactive Salesforce Users

## Overview
This solution automates the deactivation of Salesforce users who have not logged into the organization for a configurable number of days. The objective is to improve security, optimize license utilization, and ensure compliance with organizational access management policies.

The process periodically evaluates active users by comparing their LastLoginDate against a predefined inactivity threshold. Users who exceed the specified number of inactive days are automatically identified and deactivated, while exempted accounts such as system administrators, integration users, or designated service accounts can be excluded through configurable criteria.

The automation generates detailed logs and notifications to provide administrators with visibility into affected users and actions performed. By eliminating manual reviews and deactivation processes, this solution reduces administrative effort, minimizes security risks associated with dormant accounts, and helps maintain a clean and compliant Salesforce environment.

Key features include:

-Configurable inactivity period (X days).
-Automatic scheduling through Apex Scheduler.
-Exclusion of specific profiles, roles, or users.
-Audit logging and email notifications.
-Bulkified processing to support large organizations.
-Compliance with Salesforce security and governance best practices.



## The Problem It Solves
This solution enables organizations to proactively manage user access, strengthen security controls, and maximize Salesforce license efficiency through automated lifecycle management of inactive users..]

## See it in Action
![Demo GIF or Image](./assets/demo.gif)
*(Optional: Link to a Loom or YouTube walkthrough video here)*

## Quick Start Guide

### Prerequisites
- [e.g., Requires Agentforce or Service Cloud]
- [e.g., My Domain must be enabled]

### Option 1: 1-Click Install (Recommended for Admins)
Deploy this asset directly to your Sandbox or Developer Edition org without touching the command line.

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com?owner=Trailblazer-Labs&repo=your-repo-name)

### Option 2: Install via Salesforce CLI (For Developers)
If you prefer to deploy using a local environment, run the following commands:

1. Clone this repository:
   `git clone https://github.com/Trailblazer-Labs/your-repo-name.git`
2. Deploy the metadata to your target org:
   `sf project deploy start --target-org your-alias`

### Post-Installation Steps
1. Assign the necessary permission sets:
   `sf org assign permset --name Your_Perm_Set`
2. [Add any manual setup steps here, like activating a Flow or adjusting a layout]

## About the Creator
Built by [@YourGitHubUsername](https://github.com/YourGitHubUsername) as part of the Trailblazer Labs Builder in Residence Cohort.
