trigger AA_ServiceCategoryTrigger on AA_Service_Category__c (before insert, before update) {
    AA_ServiceCategoryTriggerHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}