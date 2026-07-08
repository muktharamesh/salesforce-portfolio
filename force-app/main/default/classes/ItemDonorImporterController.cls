public with sharing class ItemDonorImporterController {
    @AuraEnabled
    public static Integer importRecords(List<Item_Donor__c> records) {
        try {
            if (records == null || records.isEmpty()) {
                throw new AuraHandledException('No records to import.');
            }
            
            // Check create/insert permissions
            if (!Schema.sObjectType.Item_Donor__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to insert Item Donor staging records.');
            }

            insert records;
            return records.size();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}