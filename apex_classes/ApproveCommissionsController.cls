public with sharing class ApproveCommissionsController {

    public Id salesRegionId { get; set; }
    public Integer pageSize { get; set; }
    public Integer pageNumber { get; set; }
    public Integer totalPages { get; set; }
    public Integer totalRecords { get; set; }

    public List<PropertyWrapper> pageRecords { get; set; }
    private Set<Id> selectedIds = new Set<Id>();

    public ApproveCommissionsController() {
        pageSize = 10;
        pageNumber = 1;
        salesRegionId = ApexPages.currentPage().getParameters().get('regionId') != null ?
            (Id)ApexPages.currentPage().getParameters().get('regionId') : null;

        loadPage();
    }

  
    public class PropertyWrapper {
        public Property__c record { get; set; }
        public Boolean selected { get; set; }

        public PropertyWrapper(Property__c p, Set<Id> selectedSet) {
            record = p;
            selected = selectedSet != null && selectedSet.contains(p.Id);
        }
    }

   
    public PageReference loadPage() {
        pageRecords = new List<PropertyWrapper>();

        if (salesRegionId == null) {
            totalRecords = 0;
            totalPages = 1;
            return null;
        }

        
        List<Sales_Office__c> offices = [
            SELECT Id FROM Sales_Office__c
            WHERE Sales_Region__c = :salesRegionId
        ];

        if (offices.isEmpty()) {
            totalRecords = 0;
            totalPages = 1;
            return null;
        }

        Set<Id> officeIds = new Set<Id>();
        for (Sales_Office__c o : offices) officeIds.add(o.Id);

       
        totalRecords = [
            SELECT COUNT()
            FROM Property__c
            WHERE Sales_Office__c IN :officeIds
              AND Status__c = 'Closed Pending Approval'
        ];

        totalPages = (Integer)Math.ceil((Double) totalRecords / (Double)pageSize);
        if (totalPages < 1) totalPages = 1;

        if (pageNumber < 1) pageNumber = 1;
        if (pageNumber > totalPages) pageNumber = totalPages;

        Integer offsetValue = (pageNumber - 1) * pageSize;

        
        List<Property__c> props = [
            SELECT Id, Name, Sales_Price__c, Agent__c,
                   Agent_Commission_Percentage__c, Agent_Commission_Amount__c,
                   Sales_Office__c, Sale_Date__c, Status__c
            FROM Property__c
            WHERE Sales_Office__c IN :officeIds
              AND Status__c = 'Closed Pending Approval'
            ORDER BY Sale_Date__c DESC NULLS LAST, Name
            LIMIT :pageSize OFFSET :offsetValue
        ];

        for (Property__c p : props) {
            pageRecords.add(new PropertyWrapper(p, selectedIds));
        }

        return null;
    }

   
    public PageReference firstPage() { pageNumber = 1; loadPage(); return null; }
    public PageReference prevPage() { if (pageNumber > 1) pageNumber--; loadPage(); return null; }
    public PageReference nextPage() { if (pageNumber < totalPages) pageNumber++; loadPage(); return null; }
    public PageReference lastPage() { pageNumber = totalPages; loadPage(); return null; }

    public String getPageInfo() {
        return 'Page ' + pageNumber + ' of ' + totalPages;
    }

    
    public PageReference syncSelections() {
        for (PropertyWrapper w : pageRecords) {
            if (w.selected) selectedIds.add(w.record.Id);
            else selectedIds.remove(w.record.Id);
        }
        return null;
    }

    
    public PageReference approveSelected() {
        syncSelections();

        if (selectedIds.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'No properties selected.'));
            return null;
        }

        
        List<Property__c> approveList = [
            SELECT Id, Agent__c, Sales_Price__c, Status__c,
                   Agent_Commission_Percentage__c, Agent_Commission_Amount__c
            FROM Property__c
            WHERE Id IN :selectedIds
              AND Status__c = 'Closed Pending Approval'
            FOR UPDATE
        ];

        if (approveList.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Selected properties are not available for approval.'
            ));
            return null;
        }

        
        Map<Id, Decimal> salesAdd = new Map<Id, Decimal>();
        Map<Id, Decimal> commAdd = new Map<Id, Decimal>();

       
        for (Property__c p : approveList) {

            p.Status__c = 'Closed Approved';

           
            if (p.Agent__c != null && p.Agent_Commission_Percentage__c == null) {
                Contact c = [
                    SELECT Default_Commission_Split_c__c
                    FROM Contact
                    WHERE Id = :p.Agent__c
                    LIMIT 1
                ];
                p.Agent_Commission_Percentage__c = c.Default_Commission_Split_c__c;
            }

           
            Decimal price = p.Sales_Price__c == null ? 0 : p.Sales_Price__c;
            Decimal pct   = p.Agent_Commission_Percentage__c == null ? 0 : p.Agent_Commission_Percentage__c;
            Decimal comm  = (price * pct) / 100;

            p.Agent_Commission_Amount__c = comm;

           
            if (p.Agent__c != null) {
                salesAdd.put(p.Agent__c,
                    (salesAdd.containsKey(p.Agent__c) ? salesAdd.get(p.Agent__c) : 0) + price);

                commAdd.put(p.Agent__c,
                    (commAdd.containsKey(p.Agent__c) ? commAdd.get(p.Agent__c) : 0) + comm);
            }
        }

        
        update approveList;

        
        if (!salesAdd.isEmpty()) {
            List<Contact> updateContacts = new List<Contact>();
            Map<Id, Contact> cMap = new Map<Id, Contact>([
                SELECT Id,
                       Year_to_Date_Total_Sales_c__c,
                       Year_to_Date_Total_Commissions__c
                FROM Contact
                WHERE Id IN :salesAdd.keySet()
            ]);

            for (Id aId : salesAdd.keySet()) {
                Contact c = cMap.get(aId);

                c.Year_to_Date_Total_Sales_c__c =
                    (c.Year_to_Date_Total_Sales_c__c == null ? 0 : c.Year_to_Date_Total_Sales_c__c)
                    + salesAdd.get(aId);

                c.Year_to_Date_Total_Commissions__c =
                    (c.Year_to_Date_Total_Commissions__c == null ? 0 : c.Year_to_Date_Total_Commissions__c)
                    + commAdd.get(aId);

                updateContacts.add(c);
            }

            update updateContacts;
        }

        
        for (Property__c p : approveList) selectedIds.remove(p.Id);

        loadPage();
        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.CONFIRM,
            'Approved ' + approveList.size() + ' property(ies).'
        ));

        return null;
    }

  
    public PageReference rejectSelected() {
        syncSelections();

        if (selectedIds.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'No properties selected.'));
            return null;
        }

        List<Property__c> rejectList = [
            SELECT Id, Agent__c, Status__c,
                   Agent_Commission_Amount__c,
                   Agent_Commission_Percentage__c
            FROM Property__c
            WHERE Id IN :selectedIds
              AND Status__c = 'Closed Pending Approval'
            FOR UPDATE
        ];

        if (rejectList.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'Selected properties not available for rejection.'
            ));
            return null;
        }

        for (Property__c p : rejectList) {
            p.Status__c = 'Open';
            p.Agent__c = null;
            p.Agent_Commission_Amount__c = null;
            p.Agent_Commission_Percentage__c = null;
        }

        update rejectList;

        for (Property__c p : rejectList) {
            selectedIds.remove(p.Id);
        }

        loadPage();
        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.CONFIRM,
            'Rejected ' + rejectList.size() + ' property(ies).'
        ));

        return null;
    }

   
    public PageReference cancel() {
        PageReference p = new PageReference('/' + salesRegionId);
        p.setRedirect(true);
        return p;
    }

    public Integer getSelectedCount() {
        return selectedIds.size();
    }
}