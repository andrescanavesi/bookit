public without sharing class AA_EmailEventHandler {
    
    // TODO: Mover a Custom Metadata Type o Custom Setting en el futuro
    // para habilitar/deshabilitar por entorno (sandbox vs prod).
    private static final Set<String> ALLOWED_EMAILS = new Set<String>{
        'andres.canavesi@gmail.com', // <-- Agrega aquí tus correos de prueba
        'test@bookit.com'
    };
    
    public static void handle(List<AA_Send_Email_Event__e> events) {
        // Inicializamos el logger en false para acumular errores y publicar al final (Bulkified)
        AA_Logger logger = new AA_Logger(false);
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        for (AA_Send_Email_Event__e evt : events) {
            try {
                // 1. Deserializar el JSON del payload a nuestra clase Wrapper
                AA_EmailRequest request = (AA_EmailRequest) JSON.deserialize(evt.Payload__c, AA_EmailRequest.class);
                
                // 2. Construir el objeto SingleEmailMessage
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                if (request.toAddresses != null && !request.toAddresses.isEmpty()) {
                    List<String> validAddresses = new List<String>();
                    for (String addr : request.toAddresses) {
                        if (ALLOWED_EMAILS.contains(addr.toLowerCase())) {
                            validAddresses.add(addr);
                        } else {
                            logger.info('Email bloqueado por seguridad (no está en ALLOWED_EMAILS): ' + addr);
                        }
                    }
                    
                    // Si después de filtrar no queda ningún destinatario válido, descartamos este email
                    if (validAddresses.isEmpty()) {
                        continue;
                    }
                    
                    mail.setToAddresses(validAddresses);
                }
                if (String.isNotBlank(request.templateId)) {
                    mail.setTemplateId(request.templateId);
                }
                if (String.isNotBlank(request.targetObjectId)) {
                    mail.setTargetObjectId(request.targetObjectId);
                }
                if (String.isNotBlank(request.whatId)) {
                    mail.setWhatId(request.whatId);
                }
                if (String.isNotBlank(request.subject)) {
                    mail.setSubject(request.subject);
                }
                if (String.isNotBlank(request.htmlBody)) {
                    mail.setHtmlBody(request.htmlBody);
                }
                if (String.isNotBlank(request.plainTextBody)) {
                    mail.setPlainTextBody(request.plainTextBody);
                }
                if (request.saveAsActivity != null) {
                    mail.setSaveAsActivity(request.saveAsActivity);
                }
                
                // 3. Agregar a la lista masiva
                emailsToSend.add(mail);
                
            } catch (Exception e) {
                // Registrar el error
                logger.error('Error construyendo email del evento: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            }
        }
        
        // 4. Enviar todos los emails en una sola llamada (Bulkified)
        if (!emailsToSend.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailsToSend, false); 
                
                // 5. Revisar resultados para registrar errores
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        for (Messaging.SendEmailError err : result.getErrors()) {
                            logger.error('Error de envío de Salesforce: ' + err.getMessage());
                        }
                    }
                }
            } catch (Exception e) {
                 logger.error('Excepción global al enviar lista de emails: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            }
        }
        
        // Publicar los logs acumulados al final de la ejecución
        logger.publish();
    }
}
