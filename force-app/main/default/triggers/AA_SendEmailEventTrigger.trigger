trigger AA_SendEmailEventTrigger on AA_Send_Email_Event__e (after insert) {
    AA_EmailEventHandler.handle(Trigger.new);
}