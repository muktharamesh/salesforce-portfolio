trigger ItemDonorTrigger on Item_Donor__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ItemDonorTriggerHandler.handleAfterInsert(Trigger.new);
    }
}