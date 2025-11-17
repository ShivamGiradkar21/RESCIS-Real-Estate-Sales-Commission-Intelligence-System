Handler class

public class PropertyTriggerHandler {
    private static final Decimal AGENCY_COMMISSION_RATE = 0.03;

    public static void beforeInsert(List<Property__c> newList) {
        setAgentCommissionPercentageForClaims(newList, null);
        setAgentCommissionAmountForApprovals(newList, null);
    }

    public static void beforeUpdate(List<Property__c> newList, Map<Id, Property__c> oldMap) {
        setAgentCommissionPercentageForClaims(newList, oldMap);
        setAgentCommissionAmountForApprovals(newList, oldMap);
    }

    private static void setAgentCommissionPercentageForClaims(List<Property__c> newList, Map<Id, Property__c> oldMap) {
        Set<Id> contactIds = new Set<Id>();
        for (Property__c p : newList) {
            String newStatus = p.Status__c;
            String oldStatus = (oldMap != null && oldMap.containsKey(p.Id)) ? oldMap.get(p.Id).Status__c : null;
            if (p.Agent__c != null && 'Working'.equalsIgnoreCase(newStatus) && !('Working'.equalsIgnoreCase(oldStatus))) {
                if (p.Agent_Commission_Percentage__c == null) contactIds.add(p.Agent__c);
            }
        }
        if (contactIds.isEmpty()) return;

        Map<Id, Contact> contacts = new Map<Id, Contact>(
            [SELECT Id, Default_Commission_Split_c__c FROM Contact WHERE Id IN :contactIds]
        );

        for (Property__c p : newList) {
            if (p.Agent__c != null && 'Working'.equalsIgnoreCase(p.Status__c) && p.Agent_Commission_Percentage__c == null) {
                Contact c = contacts.get(p.Agent__c);
                if (c != null && c.Default_Commission_Split_c__c != null) {
                    p.Agent_Commission_Percentage__c = c.Default_Commission_Split_c__c;
                }
            }
        }
    }

    private static void setAgentCommissionAmountForApprovals(List<Property__c> newList, Map<Id, Property__c> oldMap) {
        for (Property__c p : newList) {
            String newStatus = p.Status__c;
            String oldStatus = (oldMap != null && oldMap.containsKey(p.Id)) ? oldMap.get(p.Id).Status__c : null;
            if ('Closed Approved'.equalsIgnoreCase(newStatus) && !'Closed Approved'.equalsIgnoreCase(oldStatus)) {
                if (p.Sales_Price__c != null) {
                    Decimal agentPct = p.Agent_Commission_Percentage__c;
                    if (agentPct == null && p.Agent__c != null) {
                        Contact c = [SELECT Default_Commission_Split_c__c FROM Contact WHERE Id = :p.Agent__c LIMIT 1];
                        agentPct = c.Default_Commission_Split_c__c;
                    }
                    if (agentPct == null) agentPct = 0;
                    Decimal commission = calculateCommission(p.Sales_Price__c, agentPct);
                    p.Agent_Commission_Amount__c = commission;
                }
            }
        }
    }

   private static Decimal calculateCommission(Decimal salesPrice, Decimal agentPercent) {
    if (salesPrice == null) return 0;
    if (agentPercent == null) agentPercent = 0;
    // agentPercent is stored like 40 for 40% -> convert to fraction by dividing by 100
    return salesPrice * AGENCY_COMMISSION_RATE * (agentPercent / 100);
}


    public static void afterInsert(List<Property__c> newList) {
        processStatusTransitions(null, newList);
    }

    public static void afterUpdate(List<Property__c> newList, Map<Id, Property__c> oldMap) {
        processStatusTransitions(oldMap, newList);
    }

    public static void afterDelete(List<Property__c> oldList) {
        processDeletes(oldList);
    }

    public static void afterUndelete(List<Property__c> newList) {
        processStatusTransitions(null, newList);
    }

    private static Boolean isSalesIncluded(String status) {
        if (status == null) return false;
        status = status.trim();
        return 'Closed Pending Approval'.equalsIgnoreCase(status) || 'Closed Approved'.equalsIgnoreCase(status);
    }
    private static Boolean isApproved(String status) {
        if (status == null) return false;
        return 'Closed Approved'.equalsIgnoreCase(status);
    }

    private static void processStatusTransitions(Map<Id, Property__c> oldMap, List<Property__c> newList) {
        Map<Id, Decimal> contactSalesDelta = new Map<Id, Decimal>();
        Map<Id, Decimal> contactCommDelta = new Map<Id, Decimal>();
        Map<Id, Decimal> officeSalesDelta = new Map<Id, Decimal>();

        Integer currentYear = Date.today().year();

        for (Property__c newRec : newList) {
            Property__c oldRec = (oldMap != null && oldMap.containsKey(newRec.Id)) ? oldMap.get(newRec.Id) : null;
            String oldStatus = (oldRec == null) ? null : oldRec.Status__c;
            String newStatus = newRec.Status__c;

            Boolean oldHasSales = isSalesIncluded(oldStatus);
            Boolean newHasSales = isSalesIncluded(newStatus);

            Date relevantDateNew = newRec.Sale_Date__c;
            Date relevantDateOld = (oldRec != null) ? oldRec.Sale_Date__c : null;

            if (newHasSales && !oldHasSales) {
                if (newRec.Sales_Price__c != null && relevantDateNew != null && relevantDateNew.year() == currentYear) {
                    if (newRec.Agent__c != null) contactSalesDelta.put(newRec.Agent__c, (contactSalesDelta.containsKey(newRec.Agent__c) ? contactSalesDelta.get(newRec.Agent__c) : 0) + newRec.Sales_Price__c);
                    if (newRec.Sales_Office__c != null) officeSalesDelta.put(newRec.Sales_Office__c, (officeSalesDelta.containsKey(newRec.Sales_Office__c) ? officeSalesDelta.get(newRec.Sales_Office__c) : 0) + newRec.Sales_Price__c);
                }
            }
            if (oldHasSales && !newHasSales && oldRec != null) {
                if (oldRec.Sales_Price__c != null && relevantDateOld != null && relevantDateOld.year() == currentYear) {
                    if (oldRec.Agent__c != null) contactSalesDelta.put(oldRec.Agent__c, (contactSalesDelta.containsKey(oldRec.Agent__c) ? contactSalesDelta.get(oldRec.Agent__c) : 0) - oldRec.Sales_Price__c);
                    if (oldRec.Sales_Office__c != null) officeSalesDelta.put(oldRec.Sales_Office__c, (officeSalesDelta.containsKey(oldRec.Sales_Office__c) ? officeSalesDelta.get(oldRec.Sales_Office__c) : 0) - oldRec.Sales_Price__c);
                }
            }

            Boolean oldApproved = isApproved(oldStatus);
            Boolean newApproved = isApproved(newStatus);

            if (newApproved && !oldApproved) {
                Decimal commission = (newRec.Agent_Commission_Amount__c != null) ? newRec.Agent_Commission_Amount__c
                    : calculateCommission(newRec.Sales_Price__c, newRec.Agent_Commission_Percentage__c);
                if (commission != null && newRec.Agent__c != null) {
                    contactCommDelta.put(newRec.Agent__c, (contactCommDelta.containsKey(newRec.Agent__c) ? contactCommDelta.get(newRec.Agent__c) : 0) + commission);
                }
            }
            if (oldApproved && !newApproved && oldRec != null) {
                Decimal oldComm = (oldRec.Agent_Commission_Amount__c != null) ? oldRec.Agent_Commission_Amount__c
                    : calculateCommission(oldRec.Sales_Price__c, oldRec.Agent_Commission_Percentage__c);
                if (oldComm != null && oldRec.Agent__c != null) {
                    contactCommDelta.put(oldRec.Agent__c, (contactCommDelta.containsKey(oldRec.Agent__c) ? contactCommDelta.get(oldRec.Agent__c) : 0) - oldComm);
                }
            }
        }

        if (!contactSalesDelta.isEmpty() || !contactCommDelta.isEmpty()) {
            Set<Id> contactIds = new Set<Id>();
            contactIds.addAll(contactSalesDelta.keySet());
            contactIds.addAll(contactCommDelta.keySet());
            if (!contactIds.isEmpty()) {
                List<Contact> contactsToUpdate = new List<Contact>();
                for (Contact c : [SELECT Id, Year_to_Date_Total_Sales_c__c, Year_to_Date_Total_Commissions__c FROM Contact WHERE Id IN :contactIds]) {
                    Decimal salesCurrent = (c.Year_to_Date_Total_Sales_c__c == null) ? 0 : c.Year_to_Date_Total_Sales_c__c;
                    Decimal commCurrent = (c.Year_to_Date_Total_Commissions__c == null) ? 0 : c.Year_to_Date_Total_Commissions__c;
                    Decimal ds = (contactSalesDelta.containsKey(c.Id) ? contactSalesDelta.get(c.Id) : 0);
                    Decimal dc = (contactCommDelta.containsKey(c.Id) ? contactCommDelta.get(c.Id) : 0);
                    c.Year_to_Date_Total_Sales_c__c = salesCurrent + ds;
                    c.Year_to_Date_Total_Commissions__c = commCurrent + dc;
                    contactsToUpdate.add(c);
                }
                if (!contactsToUpdate.isEmpty()) {
                    try {
                        update contactsToUpdate;
                    } catch (Exception ex) {
                        throw ex;
                    }
                }
            }
        }

        if (!officeSalesDelta.isEmpty()) {
            Set<Id> officeIds = officeSalesDelta.keySet();
            List<Sales_Office__c> officesToUpdate = new List<Sales_Office__c>();
            for (Sales_Office__c so : [SELECT Id, Year_to_Date_Sales__c FROM Sales_Office__c WHERE Id IN :officeIds]) {
                Decimal curr = (so.Year_to_Date_Sales__c == null) ? 0 : so.Year_to_Date_Sales__c;
                Decimal delta = (officeSalesDelta.containsKey(so.Id) ? officeSalesDelta.get(so.Id) : 0);
                so.Year_to_Date_Sales__c = curr + delta;
                officesToUpdate.add(so);
            }
            if (!officesToUpdate.isEmpty()) {
                try {
                    update officesToUpdate;
                } catch (Exception ex) {
                    throw ex;
                }
            }
        }
    }

    private static void processDeletes(List<Property__c> oldList) {
        Map<Id, Decimal> contactSalesDelta = new Map<Id, Decimal>();
        Map<Id, Decimal> contactCommDelta = new Map<Id, Decimal>();
        Map<Id, Decimal> officeSalesDelta = new Map<Id, Decimal>();
        Integer currentYear = Date.today().year();

        for (Property__c oldRec : oldList) {
            String oldStatus = oldRec.Status__c;
            if (isSalesIncluded(oldStatus)) {
                if (oldRec.Sales_Price__c != null && oldRec.Sale_Date__c != null && oldRec.Sale_Date__c.year() == currentYear) {
                    if (oldRec.Agent__c != null) contactSalesDelta.put(oldRec.Agent__c, (contactSalesDelta.containsKey(oldRec.Agent__c) ? contactSalesDelta.get(oldRec.Agent__c) : 0) - oldRec.Sales_Price__c);
                    if (oldRec.Sales_Office__c != null) officeSalesDelta.put(oldRec.Sales_Office__c, (officeSalesDelta.containsKey(oldRec.Sales_Office__c) ? officeSalesDelta.get(oldRec.Sales_Office__c) : 0) - oldRec.Sales_Price__c);
                }
            }
            if (isApproved(oldStatus)) {
                Decimal oldComm = (oldRec.Agent_Commission_Amount__c != null) ? oldRec.Agent_Commission_Amount__c : calculateCommission(oldRec.Sales_Price__c, oldRec.Agent_Commission_Percentage__c);
                if (oldComm != null && oldRec.Agent__c != null) {
                    contactCommDelta.put(oldRec.Agent__c, (contactCommDelta.containsKey(oldRec.Agent__c) ? contactCommDelta.get(oldRec.Agent__c) : 0) - oldComm);
                }
            }
        }

        if (!contactSalesDelta.isEmpty() || !contactCommDelta.isEmpty()) {
            Set<Id> contactIds = new Set<Id>();
            contactIds.addAll(contactSalesDelta.keySet());
            contactIds.addAll(contactCommDelta.keySet());
            List<Contact> contactsToUpdate = new List<Contact>();
            for (Contact c : [SELECT Id, Year_to_Date_Total_Sales_c__c, Year_to_Date_Total_Commissions__c FROM Contact WHERE Id IN :contactIds]) {
                Decimal salesCurrent = (c.Year_to_Date_Total_Sales_c__c == null) ? 0 : c.Year_to_Date_Total_Sales_c__c;
                Decimal commCurrent = (c.Year_to_Date_Total_Commissions__c == null) ? 0 : c.Year_to_Date_Total_Commissions__c;
                Decimal ds = (contactSalesDelta.containsKey(c.Id) ? contactSalesDelta.get(c.Id) : 0);
                Decimal dc = (contactCommDelta.containsKey(c.Id) ? contactCommDelta.get(c.Id) : 0);
                c.Year_to_Date_Total_Sales_c__c = salesCurrent + ds;
                c.Year_to_Date_Total_Commissions__c = commCurrent + dc;
                contactsToUpdate.add(c);
            }
            if (!contactsToUpdate.isEmpty()) update contactsToUpdate;
        }

        if (!officeSalesDelta.isEmpty()) {
            Set<Id> officeIds = officeSalesDelta.keySet();
            List<Sales_Office__c> officesToUpdate = new List<Sales_Office__c>();
            for (Sales_Office__c so : [SELECT Id, Year_to_Date_Sales__c FROM Sales_Office__c WHERE Id IN :officeIds]) {
                Decimal curr = (so.Year_to_Date_Sales__c == null) ? 0 : so.Year_to_Date_Sales__c;
                Decimal delta = (officeSalesDelta.containsKey(so.Id) ? officeSalesDelta.get(so.Id) : 0);
                so.Year_to_Date_Sales__c = curr + delta;
                officesToUpdate.add(so);
            }
            if (!officesToUpdate.isEmpty()) update officesToUpdate;
        }
    }
}