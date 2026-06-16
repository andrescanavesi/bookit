public class AA_EmailService {
    
    public static void publishEmail(AA_EmailRequest request) {
        AA_Logger logger = new AA_Logger(true); // En el contexto síncrono, podemos publicar inmediatamente
        AA_Send_Email_Event__e evt = new AA_Send_Email_Event__e();
        evt.Payload__c = JSON.serialize(request);
        
        Database.SaveResult sr = EventBus.publish(evt);
        
        if (!sr.isSuccess()) {
            for(Database.Error err : sr.getErrors()) {
                logger.error('Error publicando el evento de email: ' + err.getMessage());
            }
        }
    }
}
