trigger AA_EmployeeTrigger on AA_Employee__c (before insert, before update) {
    AA_EmployeeTriggerHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}
