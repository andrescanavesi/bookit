trigger AA_BranchWorkingHourTrigger on AA_Branch_Working_Hour__c (before insert, before update) {
    AA_BranchWorkingHourTriggerHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}