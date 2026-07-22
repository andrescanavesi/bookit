public with sharing class AA_EmployeeAppointmentsCtrl {
    
    @AuraEnabled(cacheable=true)
    public static List<AA_Employee__c> getEmployees() {
        // Find the employee record for the current user
        List<AA_Employee__c> currentUserEmp = [
            SELECT Id, Business_Branch__c 
            FROM AA_Employee__c 
            WHERE User__c = :UserInfo.getUserId() 
            LIMIT 1
        ];
        
        Id branchId = null;
        if (!currentUserEmp.isEmpty()) {
            branchId = currentUserEmp[0].Business_Branch__c;
        }
        
        // Filter active employees by the branch of the running user
        if (branchId != null) {
            return [
                SELECT Id, Name, First_Name__c, Last_Name__c, User__c 
                FROM AA_Employee__c 
                WHERE Is_Active__c = true AND Business_Branch__c = :branchId
                ORDER BY First_Name__c ASC
            ];
        } else {
            // Fallback: If running user is not tied to a branch, return all active employees
            return [
                SELECT Id, Name, First_Name__c, Last_Name__c, User__c 
                FROM AA_Employee__c 
                WHERE Is_Active__c = true
                ORDER BY First_Name__c ASC
            ];
        }
    }
    
    @AuraEnabled
    public static List<AA_Appointment__c> getPendingAppointments(Id employeeId, Date selectedDate) {
        // Fetch appointments for the selected date and employee that are not done, cancelled or no-show
        return [
            SELECT Id, Name, Start_Date_Time__c, End_Date_Time__c, Status__c,
                   Payment_Method__c, Payment_Amount__c, Customer_Comments__c, Internal_Comments__c,
                   Service__r.Name, Service__r.Price__c,
                   Customer__r.Id, Customer__r.First_Name__c, Customer__r.Last_Name__c, 
                   Customer__r.Has_Allergy_Esmalte_Semipermanente__c, Customer__r.Is_New_Customer__c,
                   Customer__r.Comments_From_Customer__c, Customer__r.Internal_Comments__c
            FROM AA_Appointment__c
            WHERE Employee__c = :employeeId
              AND DAY_ONLY(Start_Date_Time__c) = :selectedDate
              AND Status__c NOT IN ('Cancelled', 'No Show', 'Done')
            ORDER BY Start_Date_Time__c ASC
        ];
    }
    
    @AuraEnabled
    public static void saveAppointmentDetails(Map<String, Object> appointmentData, Map<String, Object> customerData) {
        try {
            // Update Appointment
            if (appointmentData != null && appointmentData.containsKey('Id')) {
                AA_Appointment__c appt = new AA_Appointment__c(Id = (Id)appointmentData.get('Id'));
                if (appointmentData.containsKey('Status__c')) {
                    appt.Status__c = (String)appointmentData.get('Status__c');
                }
                if (appointmentData.containsKey('Payment_Method__c')) {
                    appt.Payment_Method__c = (String)appointmentData.get('Payment_Method__c');
                }
                if (appointmentData.containsKey('Payment_Amount__c') && appointmentData.get('Payment_Amount__c') != null) {
                    appt.Payment_Amount__c = Decimal.valueOf(String.valueOf(appointmentData.get('Payment_Amount__c')));
                }
                if (appointmentData.containsKey('Customer_Comments__c')) {
                    appt.Customer_Comments__c = (String)appointmentData.get('Customer_Comments__c');
                }
                if (appointmentData.containsKey('Internal_Comments__c')) {
                    appt.Internal_Comments__c = (String)appointmentData.get('Internal_Comments__c');
                }
                update appt;
            }
            
            // Update Customer
            if (customerData != null && customerData.containsKey('Id')) {
                AA_Customer__c cust = new AA_Customer__c(Id = (Id)customerData.get('Id'));
                if (customerData.containsKey('Comments_From_Customer__c')) {
                    cust.Comments_From_Customer__c = (String)customerData.get('Comments_From_Customer__c');
                }
                if (customerData.containsKey('Internal_Comments__c')) {
                    cust.Internal_Comments__c = (String)customerData.get('Internal_Comments__c');
                }
                update cust;
            }
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
