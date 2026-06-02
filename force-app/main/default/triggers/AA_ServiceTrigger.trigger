trigger AA_ServiceTrigger on AA_Service__c (before insert, before update) {
    AA_ServiceTriggerHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}
