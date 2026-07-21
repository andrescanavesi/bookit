@IsTest
private class AA_CustomerLookupControllerTest {
    
    @testSetup
    static void setupTestData() {
        AA_Business__c business = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(business.Id, true);
        AA_Employee__c emp = AA_TestDataFactory.createEmployee(branch.Id, UserInfo.getUserId(), true);
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(business.Id, true);
    }
    
    @isTest
    static void testSearchCustomers() {
        Test.startTest();
        // Should return the created customer
        List<AA_Customer__c> results = AA_CustomerLookupController.searchCustomers('Test');
        System.assert(results.size() > 0, 'Should find at least one customer');
        
        // Short search term
        List<AA_Customer__c> shortResults = AA_CustomerLookupController.searchCustomers('Te');
        System.assertEquals(0, shortResults.size(), 'Should return empty for short search term');
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCustomer_Success() {
        Test.startTest();
        AA_Customer__c newCust = AA_CustomerLookupController.createCustomer('New', 'Customer', '099123456');
        System.assertNotEquals(null, newCust.Id, 'Customer should be created successfully');
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCustomer_MissingName() {
        Test.startTest();
        try {
            AA_CustomerLookupController.createCustomer('', 'Customer', '099123456');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected validation error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCustomer_DuplicatePhone() {
        AA_Customer__c existingCust = [SELECT Phone_Number__c FROM AA_Customer__c LIMIT 1];
        
        Test.startTest();
        try {
            AA_CustomerLookupController.createCustomer('Another', 'Customer', existingCust.Phone_Number__c);
            System.assert(false, 'Should have thrown duplicate exception');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected duplicate error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetBusinessId_NoEmployee() {
        // Run as a user who doesn't have an employee record
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1]; 
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='bookittestuser123' + DateTime.now().getTime() + '@testorg.com');
        insert u;
        
        System.runAs(u) {
            Test.startTest();
            try {
                AA_CustomerLookupController.searchCustomers('Test');
                System.assert(false, 'Should throw exception for no employee');
            } catch (AuraHandledException e) {
                System.assert(true, 'Expected no employee error');
            }
            Test.stopTest();
        }
    }
}
