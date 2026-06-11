public with sharing class AA_SalonRemindersController {

    public class RemindersDataWrapper {
        @AuraEnabled public List<AA_Appointment__c> confirmations {get;set;}
        @AuraEnabled public List<AA_Appointment__c> reminders {get;set;}
        @AuraEnabled public List<AA_Appointment__c> awaiting {get;set;}
        @AuraEnabled public List<AA_Appointment__c> pendingPayments {get;set;}
    }

    private static Id getBusinessId(){
        List<AA_Employee__c> employees = [SELECT Id, Name, Business_Id__c FROM AA_Employee__c 
        WHERE User__c = :UserInfo.getUserId() ORDER BY Name ASC];

        if (employees.isEmpty()) {
            throw new AuraHandledException('El empleado no está configurado como usuario');
        }
        
        AA_Employee__c currentEmployee = employees[0];
        return currentEmployee.Business_Id__c;
    }

    @AuraEnabled(cacheable=true)
    public static RemindersDataWrapper getRemindersData() {
        AA_Logger logger = new AA_Logger(true);
        try {
            Id businessId = getBusinessId();
            RemindersDataWrapper wrapper = new RemindersDataWrapper();

            String baseQuery = 'SELECT Id, Name, Start_Date_Time__c, Status__c, Payment_Amount__c, ' +
                               'Customer__r.First_Name__c, Customer__r.Last_Name__c, Customer__r.Phone_Number__c, ' +
                               'Service__r.Name, Service__r.Display_Name__c, Service__r.Duration_Minutes__c, Service__r.Price__c, ' +
                               'Service__r.Business_Branch__r.Address__c, ' +
                               'Service__r.Business_Branch__r.Business__r.Cancellation_Policy__c, ' +
                               'Service__r.Business_Branch__r.Business__r.Book_Confirmation_Message_Template__c, ' +
                               'Service__r.Business_Branch__r.Business__r.Appointment_Reminder_Message_Template__c, ' +
                               'Service__r.Business_Branch__r.Business__r.Pending_Payment_Message_Template__c ' +
                               'FROM AA_Appointment__c ' +
                               'WHERE Service__r.Business_Branch__r.Business__c = :businessId ';

            // 1. Confirmaciones: Is_Book_Confirmation_Sent__c = false
            // Filtramos citas futuras y que no estén canceladas/completadas
            wrapper.confirmations = Database.query(baseQuery + 
                'AND Is_Book_Confirmation_Sent__c = false ' +
                'AND Status__c NOT IN (\'Cancelled\', \'Done\') ' +
                'AND Start_Date_Time__c >= TODAY ' +
                'ORDER BY Start_Date_Time__c ASC');

            // 2. Recordatorios: Is_Reminder_Sent__c = false y Start_Date_Time__c en las proximas 24hs
            wrapper.reminders = Database.query(baseQuery + 
                'AND Is_Reminder_Sent__c = false ' +
                'AND Status__c NOT IN (\'Cancelled\', \'Done\') ' +
                'AND Start_Date_Time__c = NEXT_N_DAYS:1 ' +
                'ORDER BY Start_Date_Time__c ASC');

            // 3. Aguardando confirmación: Is_Customer_Confirmed__c = false y Is_Reminder_Sent__c = true
            wrapper.awaiting = Database.query(baseQuery + 
                'AND Is_Customer_Confirmed__c = false ' +
                'AND Is_Reminder_Sent__c = true ' +
                'AND Status__c NOT IN (\'Cancelled\', \'Done\') ' +
                'AND Start_Date_Time__c >= TODAY ' +
                'ORDER BY Start_Date_Time__c ASC');

            // 4. Cobros Pendientes: Status__c = 'Done' y Is_Paid__c = false
            wrapper.pendingPayments = Database.query(baseQuery + 
                'AND Status__c = \'Done\' ' +
                'AND Is_Paid__c = false ' +
                'ORDER BY Start_Date_Time__c DESC');

            return wrapper;
        } catch (Exception e) {
            String message = 'Error getting reminders data: ' + e.getMessage();
            logger.error(message + ' ' + e.getStackTraceString());
            throw new AuraHandledException(message);
        }
    }
}