public without sharing class AA_AppointmentTriggerHandler {

    public static void handleAfterInsert(List<AA_Appointment__c> newAppointments) {
        processEmails(newAppointments, null);
    }

    public static void handleAfterUpdate(List<AA_Appointment__c> newAppointments, Map<Id, AA_Appointment__c> oldMap) {
        processEmails(newAppointments, oldMap);
    }

    private static void processEmails(List<AA_Appointment__c> newAppointments, Map<Id, AA_Appointment__c> oldMap) {
        Set<Id> appointmentIdsToProcess = new Set<Id>();
        
        for (AA_Appointment__c appt : newAppointments) {
            // Process if it's an insert or if Status__c changed
            if (oldMap == null || appt.Status__c != oldMap.get(appt.Id).Status__c) {
                appointmentIdsToProcess.add(appt.Id);
            }
        }
        
        if (appointmentIdsToProcess.isEmpty()) {
            return;
        }
        
        List<AA_Appointment__c> appointmentsToProcess = [
            SELECT Id, Name, Start_Date_Time__c, End_Date_Time__c, Duration_Minutes__c, 
                   Employee__r.Name, Service__r.Name, Customer__r.Name, Status__c, 
                   Branch_Name__c, Amount__c, Business_Name__c, Business_Id__c,
                   Service__r.Business_Branch__r.Business__r.Email__c
            FROM AA_Appointment__c
            WHERE Id IN :appointmentIdsToProcess
        ];
        
        List<AA_EmailRequest> emails = new List<AA_EmailRequest>();
        
        for (AA_Appointment__c appt : appointmentsToProcess) {
            String adminEmail = appt.Service__r?.Business_Branch__r?.Business__r?.Email__c;
            
            if (String.isNotBlank(adminEmail)) {
                AA_EmailRequest req = new AA_EmailRequest();
                req.toAddresses = new List<String>{adminEmail};
                
                String actionStr = (oldMap == null) ? 'Created' : 'Status Updated';
                req.subject = 'Appointment ' + actionStr + ': ' + appt.Name;
                
                String body = 'Detalles del Appointment:\n\n';
                body += 'AA Appointment Name: ' + (appt.Name != null ? appt.Name : '') + '\n';
                body += 'Start Date Time: ' + (appt.Start_Date_Time__c != null ? appt.Start_Date_Time__c.format() : '') + '\n';
                body += 'End Date Time: ' + (appt.End_Date_Time__c != null ? appt.End_Date_Time__c.format() : '') + '\n';
                body += 'Duration Minutes: ' + (appt.Duration_Minutes__c != null ? String.valueOf(appt.Duration_Minutes__c) : '') + '\n';
                body += 'Employee: ' + (appt.Employee__r != null ? appt.Employee__r.Name : '') + '\n';
                body += 'Service: ' + (appt.Service__r != null ? appt.Service__r.Name : '') + '\n';
                body += 'Customer: ' + (appt.Customer__r != null ? appt.Customer__r.Name : '') + '\n';
                body += 'Status: ' + (appt.Status__c != null ? appt.Status__c : '') + '\n';
                body += 'Branch Name: ' + (appt.Branch_Name__c != null ? appt.Branch_Name__c : '') + '\n';
                body += 'Amount: ' + (appt.Amount__c != null ? String.valueOf(appt.Amount__c) : '') + '\n';
                body += 'Business Name: ' + (appt.Business_Name__c != null ? appt.Business_Name__c : '') + '\n';
                body += 'Business Id: ' + (appt.Business_Id__c != null ? appt.Business_Id__c : '') + '\n';
                
                req.plainTextBody = body;
                emails.add(req);
            }
        }
        
        if (!emails.isEmpty()) {
            AA_EmailService.publishEmails(emails);
        }
    }
}
