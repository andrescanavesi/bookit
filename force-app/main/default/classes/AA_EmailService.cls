public class AA_EmailService {
    
    public static void publishEmail(AA_EmailRequest request) {
        publishEmails(new List<AA_EmailRequest>{request});
    }

    public static void publishEmails(List<AA_EmailRequest> requests) {
        AA_Logger logger = new AA_Logger(true); // En el contexto síncrono, podemos publicar inmediatamente
        List<AA_Send_Email_Event__e> events = new List<AA_Send_Email_Event__e>();
        
        for (AA_EmailRequest req : requests) {
            AA_Send_Email_Event__e evt = new AA_Send_Email_Event__e();
            evt.Payload__c = JSON.serialize(req);
            events.add(evt);
        }
        
        List<Database.SaveResult> results = EventBus.publish(events);
        
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for(Database.Error err : sr.getErrors()) {
                    logger.error('Error publicando el evento de email: ' + err.getMessage());
                }
            }
        }
    }
}