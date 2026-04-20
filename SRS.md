# Software Requirements Specification

## Project Title
Vehicle Entry, Sales & Commission Management System

## 1. Purpose
This document defines the software requirements for a cross-platform mobile application for Android and iOS that manages vehicle entry, sales processing, payment capture, commission calculation, reporting, and logistics tracking.

The system is intended to streamline operational workflow from gate entry through final sale, while preserving financial correctness, operational traceability, and auditability.

## 2. Scope
The application will support the following end-to-end workflow:

1. Vehicle arrives at gate and entry details are recorded.
2. Entry data is transferred automatically to the next stage.
3. Sales details are recorded.
4. One or more payments are captured for the sale.
5. Commission values are calculated automatically from the sale data.
6. Authorized users may manually adjust commissions when required.
7. Reports are generated for operational and financial review.
8. Logistics status is tracked throughout the process.

The system is expected to run on Android and iOS through a shared mobile application and connect to a centralized backend and relational database.

## 3. Objectives
- Reduce duplicate manual data entry across process stages.
- Improve accuracy of sales, payments, and commission records.
- Support multiple payment methods within a single transaction.
- Provide visibility into vehicle progress from entry to completion.
- Generate operational and financial reports for management.
- Maintain an audit trail for critical business actions.

## 4. Stakeholders
- Gate Operators
- Sales Staff
- Cashiers / Payment Operators
- Managers / Supervisors
- Finance / Accounts Team
- Administrators

## 5. Definitions
- Vehicle Entry: Initial registration of a vehicle and related persons at the gate.
- Gross Sale: Total sale value before deductions or adjustments.
- Net Sale: Final sale amount used for business calculations such as commissions.
- Commission: Incentive amount distributed to driver, guide, local agent, and company based on business rules.
- Logistics Tracking: Monitoring the movement or operational status of a vehicle through the workflow.
- Auto Data Transfer: Reuse of previously entered data in downstream process stages without manual re-entry.

## 6. Assumptions
- The system will use a centralized backend and database.
- Users will authenticate before using protected modules.
- The commission base amount is net sale unless business rules specify otherwise.
- Multiple payment entries may belong to one sale.
- Manual commission changes will be restricted to authorized roles.
- Reporting will be based on stored transactional data rather than manual compilation.

## 7. Functional Requirements

### 7.1 User Authentication and Access
- The system shall require authenticated access for operational users.
- The system shall support role-based access control.
- The system shall restrict sensitive actions such as commission overrides and report access based on user role.

### 7.2 Gate Vehicle Entry Module
- The system shall allow creation of a vehicle entry record.
- The system shall capture at minimum:
  - Vehicle Number
  - Driver Name
  - Guide Name
  - Local Agent
  - Company Name
- The system shall timestamp each vehicle entry.
- The system shall assign a unique identifier to each vehicle entry record.
- The system shall allow retrieval of existing vehicle entries.
- The system shall maintain status of the vehicle within the workflow.

### 7.3 Automated Data Transfer Module
- The system shall automatically populate downstream forms with previously captured vehicle entry data.
- The system shall prevent users from re-entering unchanged data where auto-filled data is available.
- The system shall allow additional fields to be added in the next stage without losing transferred data.
- The system shall preserve linkage between each downstream record and its originating vehicle entry.
- The system shall include date capture for the next process stage.

### 7.4 Sales Management Module
- The system shall allow creation of a sales record linked to a vehicle entry.
- The system shall capture at minimum:
  - Gross Sale
  - Net Sale
  - Salesperson
  - Order Type
- The system shall support order type values including:
  - Order
  - Hand Delivery
- The system shall validate that required sales fields are completed before progressing to payment.
- The system shall allow authorized users to update sales data before finalization.
- The system shall retain a history or audit reference for material changes to sales values.

### 7.5 Payment Processing Module
- The system shall allow recording one or more payment entries against a single sale.
- The system shall support payment modes including:
  - CC — Credit Card
  - IC — Indian Currency (₹)
  - FC — Foreign Currency ($)
- The system shall support mixed-mode payments within one transaction.
- The system shall calculate and display the total amount from all payment entries.
- The system shall validate payment amounts against business rules.
- The system shall store each payment entry individually.
- The system shall link each payment entry to the relevant sale.
- The system shall allow users to review payment breakdown per sale.

### 7.6 Commission Calculation Module
- The system shall calculate commissions automatically based on net sale and configured business rules.
- The system shall calculate commission values for:
  - Driver
  - Guide
  - Local Agent
  - Company
- The system shall display calculated commission values before confirmation.
- The system shall support manual adjustment of commission values by authorized users.
- The system shall record both the auto-calculated value and the final approved value when an override occurs.
- The system shall require an audit trail for manual commission changes.
- The system shall associate commission records with the relevant sale and payment context.

### 7.7 Reporting Module
- The system shall generate reports for:
  - Sales
  - Commissions
  - Vehicle Entries
  - Payments
- The system shall allow filtering reports by date range.
- The system shall allow filtering reports by relevant business attributes such as salesperson, company, payment mode, or workflow status where applicable.
- The system shall present report data in a readable summary format.
- The system shall allow authorized users to access reports.

### 7.8 Logistics Tracking Module
- The system shall track the status of each vehicle through the operational workflow.
- The system shall allow users to view the current stage of a vehicle or transaction.
- The system shall maintain linkage between vehicle entry, sales, payment, and commission records.
- The system shall provide visibility into complete process flow from entry to completion.
- The system shall preserve status history or event history for traceability.

### 7.9 Audit and History
- The system shall log critical actions including:
  - Creation of vehicle entries
  - Sales creation and modification
  - Payment creation and modification
  - Commission overrides
  - Status changes
- The system shall record user identity and timestamp for audited actions.
- The system shall preserve historical records needed for review and dispute handling.

## 8. Data Requirements

### 8.1 Core Entities
The system shall maintain data structures for at least the following:
- Users
- Roles
- Vehicle Entries
- Sales
- Payments
- Commissions
- Companies
- Drivers
- Guides
- Local Agents
- Workflow Statuses or Tracking Events
- Audit Logs

### 8.2 Data Relationships
- One vehicle entry may be linked to one or more downstream operational records, subject to final business rules.
- One sale shall belong to one vehicle entry.
- One sale may contain multiple payment entries.
- One sale shall have one commission result set, with possible override history.
- Audit logs shall reference the affected business record and acting user where applicable.

## 9. Business Rules
- Vehicle entry must exist before sales processing begins.
- Sales record must exist before payment processing begins.
- Commission calculation shall occur after relevant sale and payment information is available, based on finalized business rules.
- Manual commission adjustment shall be permitted only for authorized users.
- Total payment value handling shall follow business validation rules, to be finalized during detailed design.
- Workflow status changes shall be traceable.

## 10. Non-Functional Requirements

### 10.1 Platform
- The mobile application shall support Android and iOS.
- The system shall use a shared cross-platform codebase.

### 10.2 Performance
- Common operational actions such as creating entries, loading current-stage records, and viewing sale details should respond quickly under normal usage conditions.
- Report generation should complete within an acceptable operational timeframe for expected data volume.

### 10.3 Reliability
- The system shall preserve transactional integrity for sales, payments, and commissions.
- The system shall minimize risk of duplicate or inconsistent records.

### 10.4 Security
- The system shall require authenticated access.
- The system shall enforce authorization by role.
- Sensitive financial and operational data shall be protected in transit and at rest where applicable.

### 10.5 Maintainability
- Business logic for commissions, workflow transitions, and payment validation should be centralized in backend services.
- The system should be designed in modules to allow future enhancements.

### 10.6 Auditability
- The system shall retain historical business actions required for operational review, financial reconciliation, and dispute resolution.

## 11. Out of Scope for Initial Specification
- Detailed tax handling rules
- Advanced accounting integrations
- Third-party payment gateway integrations
- Multi-branch enterprise consolidation
- Offline-first synchronization behavior
- Export format requirements such as PDF or Excel

These may be added later once business rules are clarified.

## 12. Dependencies
- Mobile frontend
- Backend API
- Centralized relational database
- Authentication and authorization mechanism
- Reporting layer over transactional data

## 13. Confirmed Decisions

### Payment Modes
- CC = Credit Card
- IC = Indian Currency (₹)
- FC = Foreign Currency ($)

### Workflow Statuses
| Status | Trigger |
|--------|---------|
| ENTERED | Gate operator creates vehicle entry |
| SALES_COMPLETE | Sale record is created |
| PAYMENT_COMPLETE | Payment recorded (if commissions not yet calculated) |
| COMPLETED | Auto-set when payment is recorded AND commissions exist; can also be set manually by a Manager |

### Role & Permissions Matrix
| Action | GATE_OPERATOR | SALES_STAFF | CASHIER | MANAGER | ADMIN |
|--------|:---:|:---:|:---:|:---:|:---:|
| Create vehicle entry | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create / edit sale | ✅ | ✅ | ❌ | ✅ | ✅ |
| Record payment | ❌ | ❌ | ✅ | ✅ | ✅ |
| View any payment history | ❌ | ❌ | ✅ | ✅ | ✅ |
| View commissions | ✅ | ✅ | ✅ | ✅ | ✅ |
| Override commission | ❌ | ❌ | ❌ | ✅ | ✅ |
| Edit commission rates | ❌ | ❌ | ❌ | ✅ | ✅ |
| View reports | ❌ | ✅ (own) | ❌ | ✅ | ✅ |
| View statements | ❌ | ❌ | ❌ | ✅ | ✅ |
| Create users | ❌ | ❌ | ❌ | ❌ | ✅ |

### Other Confirmed Rules
- One vehicle entry may have multiple sales.
- Sales may be edited after payment is recorded.
- Report export supports both PDF and Excel download.
- Account statements are available at Driver, Guide, Local Agent, and Company level, each with date filtering and PDF/Excel export.

## 14. Remaining Open Items
1. Offline support — still out of scope for MVP (confirmed).
2. Tax handling — out of scope (confirmed).
3. Multi-branch consolidation — out of scope (confirmed).

## 15. Suggested MVP Boundary
The minimum viable product should include:
- User authentication
- Gate vehicle entry
- Automatic data transfer
- Sales entry
- Multi-mode payment capture
- Automatic commission calculation
- Manual commission override for authorized users
- Basic reports
- Workflow status tracking
- Audit logs for critical actions

## 16. Summary
This system is a workflow-driven operational and financial application rather than a simple data-entry app. Its success depends on:
- accurate stage-to-stage data flow
- correct handling of payments and commissions
- strong auditability
- clear workflow tracking

These requirements provide a baseline software specification and should be refined further through business-rule confirmation and detailed technical design.
