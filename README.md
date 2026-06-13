# Salesforce Portfolio: Advanced Automations & Business Intelligence

Welcome to my Salesforce Portfolio! This repository contains the source code (Salesforce DX format) for my custom configurations, automations, and analytical solutions developed for the Salesforce platform. It demonstrates how I leverage Lightning Flow, Reports, and Dashboards to solve real-world business problems and drive data-driven decision-making.

---

## 🚀 Key Projects & Solutions

### 1. Business Automation with Lightning Flows (`force-app/main/default/flows/`)
Automating repetitive processes reduces human error and accelerates sales cycles. This repository showcases three custom flows:

*   **BetterWorld: Auto Create Contact and Opp Records** (`BetterWorld_Auto_Create_Contact_Account_and_Opp_Records`)
    *   **Business Case**: Streamlines external donor registration systems. Whenever incoming data registers, this flow automatically verifies matching records, and dynamically creates or links Contacts and Opportunities to ensure clean data pipelines.
    *   **Integration**: Connected via external [Zapier Integration](zapier/README.md) that loads BetterWorld webhook payloads directly into Salesforce.
*   **Square: Auto Create Contact, Account, and Opp Records** (`Square_Auto_Create_Contact_Account_and_Opp_Records`)
    *   **Business Case**: Reconciles point-of-sale event purchases (e.g. via Square terminals). Incoming transaction entries are parsed to automatically create/match contacts and opportunity records. (Co-developed with Stacy McDonald).
*   **Ghost Member Creation from Opportunity** (`Ghost_Member_Creation_from_Opportunity`)
    *   **Business Case**: Automates newsletter subscriptions and supporter segmentation. Triggers instantly when a new opportunity/contact is recorded, passing the dynamically calculated `Ghost_Labels__c` formula value to segment subscribers based on interest (Volunteer, Giving Circle, Events, Sponsor Universe).
    *   **Privacy Control**: Built-in filter logic programmatically excludes sensitive health-related record types (e.g. Mental Health Sessions) to ensure HIPAA compliance and supporter confidentiality.
*   **Opportunity: Email Acknowledgement Button** (`Opportunity_Email_Acknowledgement_Button`)
    *   **Business Case**: Gives account managers a rapid one-click solution. A button on the Opportunity page triggers this flow to send customized email acknowledgements to donors or customers, updating the opportunity status automatically.

---

### 📊 2. Analytics & Business Intelligence (`force-app/main/default/dashboards/` & `reports/`)
A business is only as strong as its data. I built a comprehensive reporting suite to provide executives with real-time insight into performance, donor tracking, and database hygiene.

#### 📈 Central Analytics Hub: **2026 RedHorse Dashboard**
*   **Location**: `force-app/main/default/dashboards/CustomDashboards/`
*   **Purpose**: Serves as the executive summary dashboard for year-over-year donations, giving circle performance, and marketing event transactions.

#### 📝 Reports Supporting the Dashboard (18 Custom Reports):
*   **Financial Tracking**: `X2026_Donations_dlt`, `Giving_Circle_Donor_Amount_2026_TI2`, `GAU_Report_2026_QQ0` (tracks general accounting unit allocations).
*   **Hygiene & Audits**: `Duplicate_Contact_Account_Report_AhY` (reports duplicate matches to keep database clean).
*   **Event Auditing**: `Porch_Party_Square_Transaction_MPF` and `Porch_Party_Zeffy_Transactions_pgH` (reconciling external event payments).
*   **Customer Insights**: `RFM_Report_Ns5` (segmenting donors by Recency, Frequency, and Monetary value).

---

### 🗄️ 3. Database Schema Extensions & Integrations (`force-app/main/default/objects/`)
To support integrations and advanced metrics, I designed and implemented custom objects and custom fields to expand the default Salesforce database schema:

*   **BetterWorld Custom Integration Object** (`BetterWorld_Transaction__c`)
    *   **Purpose**: A fully customized object acting as the landing table for BetterWorld transaction data.
    *   **Key Fields**: Includes fields for `Amount__c`, `Net_Amount__c`, lookup to related Opportunity (`BetterWorld_Transaction__c`), customer credentials (`Donor_Name__c`, `Email__c`, `Phone__c`), and payment attributes.
*   **Square Custom Integration Object** (`Square_Transaction__c`)
    *   **Purpose**: Custom landing table for point-of-sale transaction payloads imported from Square. (Co-developed with Stacy McDonald).
    *   **Key Fields**: Includes fields for `Amount__c`, `Processing_Fee__c`, `Square_Id__c`, `Square_Receipt__c`, customer credentials, and `Opportunity` lookup fields.
*   **Formula & Quality Control Fields**:
    *   `Opportunity.QB_Payment_Method_Formula__c`: Automates accounting mappings to QuickBooks.
    *   `Opportunity.Account_Name_for_email__c`: Supports mail merge functionality in automation alerts.
    *   `Contact.Current_Calendar_Year__c`: Computes dynamically to facilitate temporal donation comparisons.
    *   `Opportunity.Ghost_Labels__c`: Tracking indicator for temporary campaigns.
    *   `Opportunity.Square_Transaction__c`: Lookup link mapping opportunities to their source Square transactions.

---

## 🛠️ How to Deploy & Inspect

Since this repository is in **Salesforce DX (SFDX)** format, it is fully deployable to any scratch org or developer sandbox.

### Prerequisites
1. Install [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli).
2. Authorize your target Salesforce environment:
   ```bash
   sf org login web --alias target-org
   ```

### Deploying the Metadata
To deploy the flows, reports, and dashboards to your authorized org:
```bash
sf project deploy start --target-org target-org
```

---

## 📫 Contact
Feel free to connect with me to discuss Salesforce administration, development, or consulting projects!
*   **Name**: Muktha Ramesh
*   **Salesforce Org**: `muktha.rameshb@redhorse.red`
