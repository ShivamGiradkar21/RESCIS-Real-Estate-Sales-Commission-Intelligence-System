#  RESCIS – Real Estate Sales & Commission Intelligence System  
A futuristic, enterprise-grade Salesforce automation system designed to manage Real Estate Property Sales, Agent Commissions, Approvals, and Reporting.  
Built with Apex, Visualforce, SOQL, custom objects, and Lightning Dashboards — RESCIS delivers intelligence, automation, and business insights end-to-end.

---

##  Features

###  Agent Experience (Visualforce + Apex)
- Interactive UI to **view & claim properties**
- Multi-select claiming with **pagination**
- Validation: **Max 5 active (Working) properties**
- Commission % pulled automatically from agent defaults

### Manager Experience (Approval UI)
- View properties marked **Closed Pending Approval**
- Multi-select **Approve / Reject** workflow
- Automatic:
  - Commission calculation  
  - YTD Sales update  
  - YTD Commission update  


###  Analytics Suite (Reports + Dashboards)
- Commission summary grouped by agent
- Full Sales breakdown by:
  - Region  
  - Office  
  - Agent  
- KPI tiles for **Total Sales** & **Total Commission**
- Modern dashboard visuals:
  - Bar charts  
  - Donut charts  
  - Metrics  

---

##  System Architecture

### **Custom Objects**
| Object | Purpose |
|--------|----------|
| **Sales_Region__c** | Groups offices by geographic region |
| **Sales_Office__c** | Assigned to regions, parent to properties |
| **Property__c** | Tracks sale details, status, commissions |
| **Contact (Agent)** | Real estate agent with commission defaults |

### **Relationships**
- Property → Agent (Lookup)
- Property → Sales Office (Lookup)
- Sales Office → Sales Region (Lookup)

---

##  Automation Components

### **Apex Trigger – PropertyTriggerHandler**
Handles:
- Commission calculation  
- Default values  
- Status validation  
- Agent constraints  
- All business logic for Property__c

### **Apex Controller Classes**
| File | Description |
|------|-------------|
| **ClaimPropertiesController.cls** | Agent property claiming logic |
| **ApproveCommissionsController.cls** | Manager approval flow & YTD updates |

### **Visualforce Pages**
| Page | Description |
|-------|-------------|
| **ClaimProperties.page** | Agent UI: Claiming properties |
| **ApproveCommissions.page** | Manager UI: Approve / Reject |

---

##  Key Business Flow

### 1. Agent Claims Property
- Status → Working  
- Agent assigned  
- Commission % applied  
- Limit enforced  

### 2. Agents close deals → Status = Closed Pending Approval  
Automated or manually set.

### 3. Manager Approves Commissions
- Status → Closed Approved  
- Commission amount calculated  
- Contact YTD Sales updated  
- Contact YTD Commission updated  

### 4. Manager Rejects
- Status → Open  
- Clears Agent & commission info  

---

##  Dashboard Overview

### Dashboard Name:  
**RESCIS Performance Dashboard**

### Components:
-  **Total Sales (Metric)**
-  **Total Commission (Metric)**
-  **Sales by Agent (Bar Chart)**
-  **Commission by Agent (Bar Chart)**
-  **Sales by Office (Donut Chart)**
-  **Trend Lines (optional)**

---

##  Testing Scenarios

- Agent claims < 5 properties → Success  
- Agent claims 6th property → Blocked  
- Manager approves multiple properties → YTD updated  
- Manager rejects property → Reset to Open  
- Dashboard refresh → Values update instantly  

---

##  Project Structure


---

##  Outcome

RESCIS demonstrates skills in:

- Apex Trigger Development  
- Visualforce UI  
- Apex MVC controllers  
- SOQL / Record Locking  
- Data Modeling  
- Lightning Dashboards  
- Enterprise Automation Design  

Perfect for real-world Salesforce Developer/Consultant roles.

---

##  Author
**Shivam Giradkar**  

Salesforce Developer | Apex | Visualforce | LWC | Automation  



