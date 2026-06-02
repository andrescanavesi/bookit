trigger AA_EmployeeTrigger on AA_Employee__c (before insert, before update, after insert) {
    if (Trigger.isBefore) {
        AA_EmployeeTriggerHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        AA_EmployeeTriggerHandler.handleAfterInsert(Trigger.new);
    }
}