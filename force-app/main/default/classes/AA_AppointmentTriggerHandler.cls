public without sharing class AA_AppointmentTriggerHandler {

    public static void handleAfterInsert(List<AA_Appointment__c> newAppointments) {
        processEmails(newAppointments, null);
    }

    public static void handleAfterUpdate(List<AA_Appointment__c> newAppointments, Map<Id, AA_Appointment__c> oldMap) {
        processEmails(newAppointments, oldMap);
    }

    private static void processEmails(List<AA_Appointment__c> newAppointments, Map<Id, AA_Appointment__c> oldMap) {
        Set<Id> appointmentIdsToProcess = new Set<Id>();
        AA_Logger logger = new AA_Logger(true);
        for (AA_Appointment__c appt : newAppointments) {
            // Process if it's an insert or if Status__c changed
            if (oldMap == null || appt.Status__c != oldMap.get(appt.Id).Status__c) {
                appointmentIdsToProcess.add(appt.Id);
            }
        }
        logger.info('appointments to process: '+appointmentIdsToProcess.size());
        if (appointmentIdsToProcess.isEmpty()) {
            return;
        }
        
        List<AA_Appointment__c> appointmentsToProcess = [
            SELECT Id, Name, Start_Date_Time__c, End_Date_Time__c, Duration_Minutes__c, 
                   Employee__r.Name, Employee__r.First_Name__c, Employee__r.Last_Name__c, Service__r.Name, Service__r.Display_Name__c, Customer__r.Name, Customer__r.First_Name__c, Customer__r.Last_Name__c, Status__c, 
                   Branch_Name__c, Amount__c, Business_Name__c, Business_Id__c,
                   Service__r.Business_Branch__r.Business__r.Email__c
            FROM AA_Appointment__c
            WHERE Id IN :appointmentIdsToProcess
        ];
        
        // 1. Recopilar emails para buscar Usuarios y evitar los límites de Dev Org
        Set<String> adminEmails = new Set<String>();
        for (AA_Appointment__c appt : appointmentsToProcess) {
            String adminEmail = appt.Service__r?.Business_Branch__r?.Business__r?.Email__c;
            if (String.isNotBlank(adminEmail)) {
                adminEmails.add(adminEmail);
            }
        }
        
        // 2. Buscar Usuarios activos que coincidan con esos emails
        Map<String, Id> userIdByEmail = new Map<String, Id>();
        if (!adminEmails.isEmpty()) {
            for (User u : [SELECT Id, Email FROM User WHERE Email IN :adminEmails AND IsActive = true]) {
                userIdByEmail.put(u.Email, u.Id);
            }
        }
        
        List<AA_EmailRequest> emails = new List<AA_EmailRequest>();
        
        for (AA_Appointment__c appt : appointmentsToProcess) {
            String adminEmail = appt.Service__r?.Business_Branch__r?.Business__r?.Email__c;
            
            if (String.isNotBlank(adminEmail)) {
                AA_EmailRequest req = new AA_EmailRequest();
                
                // Si encontramos un usuario con ese correo, le enviamos por TargetObjectId (no gasta límite)
                if (userIdByEmail.containsKey(adminEmail)) {
                    req.targetObjectId = userIdByEmail.get(adminEmail);
                    req.saveAsActivity = false;
                } else {
                    // Si no, caemos en el comportamiento por defecto (puede dar Email limit exceeded en Dev Orgs)
                    req.toAddresses = new List<String>{adminEmail};
                }
                
                String actionStr = (oldMap == null) ? 'Nuevo turno agendado' : 'Turno actualizado';
                req.subject = '[Book It] ' + actionStr + ' (' + appt.Name + ')';
                logger.info('email with appointment to send, subject: '+req.subject);
                
                String html = '<div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px; overflow: hidden;">';
                html += '<div style="background-color: #0f0e0d; color: #faf6f0; padding: 20px; text-align: center;">';
                html += '<h2 style="margin: 0; font-size: 24px;">' + actionStr + '</h2>';
                html += '</div>';
                html += '<div style="padding: 20px; background-color: #faf6f0;">';
                html += '<p style="font-size: 16px; line-height: 1.5;">Hola,</p>';
                html += '<p style="font-size: 16px; line-height: 1.5;">Se han registrado cambios en la agenda del salón <strong>' + (appt.Business_Name__c != null ? appt.Business_Name__c : '') + '</strong>.</p>';
                
                String customerName = '';
                if (appt.Customer__r != null) {
                    if (String.isNotBlank(appt.Customer__r.First_Name__c)) {
                        customerName = appt.Customer__r.First_Name__c;
                        if (String.isNotBlank(appt.Customer__r.Last_Name__c)) {
                            customerName += ' ' + appt.Customer__r.Last_Name__c;
                        }
                    } else {
                        customerName = appt.Customer__r.Name;
                    }
                }
                
                String employeeName = '';
                if (appt.Employee__r != null) {
                    if (String.isNotBlank(appt.Employee__r.First_Name__c)) {
                        employeeName = appt.Employee__r.First_Name__c;
                        if (String.isNotBlank(appt.Employee__r.Last_Name__c)) {
                            employeeName += ' ' + appt.Employee__r.Last_Name__c;
                        }
                    } else {
                        employeeName = appt.Employee__r.Name;
                    }
                }
                
                String serviceName = '';
                if (appt.Service__r != null) {
                    if (String.isNotBlank(appt.Service__r.Display_Name__c)) {
                        serviceName = appt.Service__r.Display_Name__c;
                    } else {
                        serviceName = appt.Service__r.Name;
                    }
                }
                
                html += '<table style="width: 100%; border-collapse: collapse; margin-top: 20px; background-color: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">';
                html += '<tr style="border-bottom: 1px solid #eee;"><td style="padding: 12px; font-weight: bold; width: 40%; color: #8a7b6e;">Cliente:</td><td style="padding: 12px;">' + customerName + '</td></tr>';
                html += '<tr style="border-bottom: 1px solid #eee;"><td style="padding: 12px; font-weight: bold; color: #8a7b6e;">Servicio:</td><td style="padding: 12px;">' + serviceName + '</td></tr>';
                html += '<tr style="border-bottom: 1px solid #eee;"><td style="padding: 12px; font-weight: bold; color: #8a7b6e;">Profesional:</td><td style="padding: 12px;">' + employeeName + '</td></tr>';
                html += '<tr style="border-bottom: 1px solid #eee;"><td style="padding: 12px; font-weight: bold; color: #8a7b6e;">Fecha:</td><td style="padding: 12px;">' + (appt.Start_Date_Time__c != null ? appt.Start_Date_Time__c.format() : '') + '</td></tr>';
                html += '<tr style="border-bottom: 1px solid #eee;"><td style="padding: 12px; font-weight: bold; color: #8a7b6e;">Duración:</td><td style="padding: 12px;">' + (appt.Duration_Minutes__c != null ? String.valueOf(appt.Duration_Minutes__c) + ' min' : '') + '</td></tr>';
                html += '<tr style="border-bottom: 1px solid #eee;"><td style="padding: 12px; font-weight: bold; color: #8a7b6e;">Monto:</td><td style="padding: 12px;">$' + (appt.Amount__c != null ? String.valueOf(appt.Amount__c) : '0') + '</td></tr>';
                html += '<tr style="border-bottom: 1px solid #eee;"><td style="padding: 12px; font-weight: bold; color: #8a7b6e;">Estado:</td><td style="padding: 12px;"><span style="background-color: #e8ddd0; padding: 4px 8px; border-radius: 4px; font-size: 14px; font-weight: bold;">' + AA_Utils.translateStatus(appt.Status__c) + '</span></td></tr>';
                html += '<tr><td style="padding: 12px; font-weight: bold; color: #8a7b6e;">ID Turno:</td><td style="padding: 12px; font-size: 13px; color: #666;">' + (appt.Name != null ? appt.Name : '') + '</td></tr>';
                html += '</table>';
                
                html += '</div>';
                html += '<div style="background-color: #e5dcce; text-align: center; padding: 12px; font-size: 12px; color: #8a7b6e;">';
                html += 'Este es un mensaje automático de Bookit.<br>Por favor no responder a este correo.';
                html += '</div>';
                html += '</div>';
                
                req.htmlBody = html;
                emails.add(req);
            }
        }
        
        if (!emails.isEmpty()) {
            AA_EmailService.publishEmails(emails);
        }
    }
}