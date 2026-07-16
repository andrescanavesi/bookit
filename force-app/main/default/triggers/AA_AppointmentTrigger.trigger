trigger AA_AppointmentTrigger on AA_Appointment__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            AA_AppointmentTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AA_AppointmentTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}