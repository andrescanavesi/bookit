trigger AA_CustomerTrigger on AA_Customer__c (before insert, before update) {
    AA_CustomerTriggerHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}