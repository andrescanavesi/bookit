@IsTest
private class AA_SalonRemindersControllerTest {

    @TestSetup
    static void setupData(){
        AA_Business__c business = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(business.Id, true);
        AA_Employee__c employee = AA_TestDataFactory.createEmployee(branch.Id, UserInfo.getUserId(), true);
        
        AA_Service_Category__c category = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c service = AA_TestDataFactory.createService(branch.Id, category.Id, true);
        
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(business.Id, true);
        
        // 1. Appointment for Confirmation (Is_Book_Confirmation_Sent__c = false, Future)
        AA_Appointment__c apptConf = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = employee.Id,
            Service__c = service.Id,
            Start_Date_Time__c = Datetime.now().addDays(2),
            Status__c = 'Pending'
        );
        insert apptConf;
        
        // 2. Appointment for Reminder (Is_Reminder_Sent__c = false, Tomorrow)
        AA_Appointment__c apptRem = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = employee.Id,
            Service__c = service.Id,
            Start_Date_Time__c = Datetime.now().addDays(1),
            Status__c = 'Pending',
            Book_Confirmation_Sent_Date__c = Datetime.now()
        );
        insert apptRem;
        
        // 3. Appointment Awaiting Confirmation (Is_Customer_Confirmed__c = false, Is_Reminder_Sent__c = true)
        AA_Appointment__c apptAwaiting = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = employee.Id,
            Service__c = service.Id,
            Start_Date_Time__c = Datetime.now().addDays(2),
            Status__c = 'Pending',
            Reminder_Sent_Date__c = Datetime.now(),
            Book_Confirmation_Sent_Date__c = Datetime.now()
        );
        insert apptAwaiting;
        
        // 4. Pending Payment Appointment (Status = Done, Is_Paid__c = false)
        AA_Appointment__c apptPayment = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = employee.Id,
            Service__c = service.Id,
            Start_Date_Time__c = Datetime.now().addDays(-1),
            Status__c = 'Done'
        );
        insert apptPayment;
    }

    @IsTest
    static void testGetRemindersData() {
        Test.startTest();
        AA_SalonRemindersController.RemindersDataWrapper wrapper = AA_SalonRemindersController.getRemindersData();
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertNotEquals(null, wrapper.confirmations, 'Confirmations list should be initialized');
        System.assertNotEquals(null, wrapper.reminders, 'Reminders list should be initialized');
        System.assertNotEquals(null, wrapper.awaiting, 'Awaiting list should be initialized');
        System.assertNotEquals(null, wrapper.pendingPayments, 'Pending Payments list should be initialized');
        
        System.assertEquals(1, wrapper.confirmations.size(), 'Should have 1 appointment for confirmation');
        System.assertEquals(1, wrapper.reminders.size(), 'Should have 1 appointment for reminder');
        System.assertEquals(1, wrapper.awaiting.size(), 'Should have 1 appointment awaiting confirmation');
        System.assertEquals(1, wrapper.pendingPayments.size(), 'Should have 1 appointment pending payment');
    }
    
    @IsTest
    static void testGetRemindersData_NoEmployee() {
        // Run as a different user that is not configured as an employee
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1]; 
        User testUser = new User(
            Alias = 'standt', 
            Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', 
            LastName='Testing', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='standarduser_bookit_' + DateTime.now().getTime() + '@testorg.com'
        );
        insert testUser;
        
        Test.startTest();
        System.runAs(testUser) {
            try {
                AA_SalonRemindersController.getRemindersData();
                System.assert(false, 'Should throw an exception since user is not an employee');
            } catch (Exception e) {
                System.assertEquals('System.AuraHandledException', e.getTypeName(), 'Expected AuraHandledException');
            }
        }
        Test.stopTest();
    }
}
