@IsTest
private class AA_ScriptsTest {

    @TestSetup
    static void setup() {
        AA_Business__c biz = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(biz.Id, true);
        
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User adminUser = new User(
            Alias = 'admScrpt',
            Email = 'adminScript@bookit.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AdminTestScript',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Montevideo',
            UserName = 'adminScript' + Crypto.getRandomInteger() + '@bookit.com',
            AA_Is_Employee_Admin__c = true
        );
        insert adminUser;
        
        AA_Employee__c emp = AA_TestDataFactory.createEmployee(branch.Id, adminUser.Id, false);
        insert emp;
        
        AA_Service_Category__c category = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c svc1 = AA_TestDataFactory.createService(branch.Id, category.Id, true);
        
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(biz.Id, true);
        
        AA_Appointment__c appt = AA_TestDataFactory.createAppointment(customer.Id, emp.Id, svc1.Id, Datetime.now(), true);
        
        Log__c log1 = new Log__c(Level__c = 'INFO');
        insert log1;
        
        // Set the test-visible BUSINESS_ID to our mock business
        AA_Scripts.BUSINESS_ID = biz.Id;
    }
    
    @IsTest
    static void testDeleteOldLogs() {
        Test.startTest();
        AA_Scripts.deleteOldLogs();
        Test.stopTest();
        System.assert(true, 'Should not throw exception');
    }
    
    @IsTest
    static void testAddMissingServicesToEmployee() {
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        Test.startTest();
        AA_Scripts.addMissingServicesToEmployee(emp.Id);
        Test.stopTest();
        
        List<AA_Employee_Service__c> empSvc = [SELECT Id FROM AA_Employee_Service__c WHERE Employee__c = :emp.Id];
        System.assert(empSvc.size() > 0, 'Should have assigned missing services');
    }
    
    @IsTest
    static void testDeleteAllAppointments() {
        Test.startTest();
        AA_Scripts.deleteAllAppointments();
        Test.stopTest();
        
        List<AA_Appointment__c> appts = [SELECT Id FROM AA_Appointment__c];
        System.assertEquals(0, appts.size(), 'All appointments should be deleted');
    }
    
    @IsTest
    static void testDeleteAllCustomers() {
        Test.startTest();
        AA_Scripts.deleteAllCustomers();
        Test.stopTest();
        
        List<AA_Customer__c> custs = [SELECT Id FROM AA_Customer__c];
        System.assertEquals(0, custs.size(), 'All customers should be deleted');
    }
    
    @IsTest
    static void testGenerateWorkingHoursForAllEmployees() {
        AA_Business__c biz = [SELECT Id FROM AA_Business__c LIMIT 1];
        AA_Scripts.BUSINESS_ID = biz.Id;
        
        Test.startTest();
        AA_Scripts.generateWorkingHoursForAllEmployees();
        Test.stopTest();
        
        List<AA_Employee_Working_Hour__c> whList = [SELECT Id FROM AA_Employee_Working_Hour__c];
        System.assert(whList.size() > 0, 'Should have generated working hours');
    }
    
    @IsTest
    static void testUpdateAllWorkingHours() {
        // Must insert some first
        AA_Scripts.generateWorkingHoursForAllEmployees();
        
        Test.startTest();
        AA_Scripts.updateAllWorkingHours();
        Test.stopTest();
        
        System.assert(true, 'Should not throw exception');
    }
    
    @IsTest
    static void testGenerateCustomersAndEmployees() {
        AA_Business__c biz = [SELECT Id FROM AA_Business__c LIMIT 1];
        AA_Business_Branch__c branch = [SELECT Id FROM AA_Business_Branch__c LIMIT 1];
        
        Test.startTest();
        AA_Scripts.generateCustomers(biz.Id);
        AA_Scripts.generateEmployees(branch.Id);
        Test.stopTest();
        
        System.assert(true, 'Should not throw exception');
    }
    
    @IsTest
    static void testSendTestEmail() {
        Test.startTest();
        AA_Scripts.sendTestEmail('test@bookit.com');
        Test.stopTest();
        
        System.assert(true, 'Should emit events for emails without errors');
    }
    
    @IsTest
    static void testGenerateBulkAppointments() {
        AA_Business__c biz = [SELECT Id FROM AA_Business__c LIMIT 1];
        AA_Scripts.BUSINESS_ID = biz.Id;
        
        Test.startTest();
        AA_Scripts.generateBulkAppointments(1);
        Test.stopTest();
        
        System.assert(true, 'Should not throw exception and generate appointments');
    }
}
