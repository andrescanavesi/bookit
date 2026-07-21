@IsTest
private class AA_AppointmentTriggerHandlerTest {
    
    @TestSetup
    static void setupData() {
        AA_Business__c business = AA_TestDataFactory.createBusiness(false);
        business.Email__c = 'admin_trigger@bookit.com';
        insert business;
        
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(business.Id, true);
        
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1]; 
        User u = new User(
            Alias = 'admTrig', 
            Email='admin_trigger@bookit.com', 
            EmailEncodingKey='UTF-8', 
            LastName='AdminTrigger', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='admin_trigger' + Crypto.getRandomInteger() + '@bookit.com'
        );
        insert u;
        
        AA_Employee__c emp = AA_TestDataFactory.createEmployee(branch.Id, u.Id, true);
        
        AA_Service_Category__c category = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c service = AA_TestDataFactory.createService(branch.Id, category.Id, true);
        
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(business.Id, true);
    }
    
    @IsTest
    static void testInsertAppointment() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Test.startTest();
        // Insert creates the appointment and triggers handleAfterInsert
        AA_Appointment__c appt = AA_TestDataFactory.createAppointment(customer.Id, emp.Id, service.Id, Datetime.now(), false);
        appt.Status__c = 'Pending';
        insert appt;
        Test.stopTest();
        
        // Assert that the trigger runs without exceptions
        System.assert(appt.Id != null, 'Appointment should be inserted correctly.');
    }
    
    @IsTest
    static void testUpdateAppointmentStatus() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        AA_Appointment__c appt = AA_TestDataFactory.createAppointment(customer.Id, emp.Id, service.Id, Datetime.now(), false);
        appt.Status__c = 'Pending';
        insert appt;
        
        Test.startTest();
        // Update the status to trigger handleAfterUpdate logic
        appt.Status__c = 'Confirmed';
        update appt;
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Status__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Confirmed', updatedAppt.Status__c, 'Appointment status should be updated.');
    }
    
    @IsTest
    static void testUpdateAppointmentNoStatusChange() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        AA_Appointment__c appt = AA_TestDataFactory.createAppointment(customer.Id, emp.Id, service.Id, Datetime.now(), false);
        appt.Status__c = 'Pending';
        insert appt;
        
        Test.startTest();
        // Update something else, should not trigger the email processing for this appointment
        appt.Payment_Method__c = 'Efectivo';
        update appt;
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Payment_Method__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Efectivo', updatedAppt.Payment_Method__c, 'Appointment payment method should be updated.');
    }
    
    @IsTest
    static void testMissingBusinessEmail() {
        // Remove email from business to test the path where email is blank
        AA_Business__c business = [SELECT Id, Email__c FROM AA_Business__c LIMIT 1];
        business.Email__c = null;
        update business;
        
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Test.startTest();
        AA_Appointment__c appt = AA_TestDataFactory.createAppointment(customer.Id, emp.Id, service.Id, Datetime.now(), true);
        Test.stopTest();
        
        System.assert(appt.Id != null, 'Appointment should be inserted even if business email is missing.');
    }
}
