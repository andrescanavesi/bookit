@IsTest
private class AA_WeeklyMatrixControllerTest {
    
    @TestSetup
    static void setupData() {
        AA_Business__c business = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(business.Id, true);
        
        // Active Admin Employee
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1]; 
        User adminUser = new User(
            Alias = 'adminU', 
            Email='admin@testorg.com', 
            EmailEncodingKey='UTF-8', 
            LastName='Admin', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='admin_' + DateTime.now().getTime() + '@testorg.com',
            AA_Is_Employee_Admin__c = true
        );
        insert adminUser;
        
        AA_Employee__c employee = AA_TestDataFactory.createEmployee(branch.Id, adminUser.Id, false);
        employee.Is_Active__c = true;
        insert employee;
        
        // Setup Branch Working Hours for Monday
        AA_Branch_Working_Hour__c bwh = new AA_Branch_Working_Hour__c(
            Business_Branch__c = branch.Id,
            Day_Of_Week__c = 'Monday',
            Open_Time__c = Time.newInstance(9, 0, 0, 0),
            Close_Time__c = Time.newInstance(18, 0, 0, 0),
            Admin_Open_Time__c = Time.newInstance(8, 0, 0, 0),
            Admin_Close_Time__c = Time.newInstance(19, 0, 0, 0)
        );
        insert bwh;
        
        // Setup Employee Working Hours for Monday
        AA_TestDataFactory.createWorkingHour(employee.Id, 'Monday', Time.newInstance(9, 0, 0, 0), Time.newInstance(18, 0, 0, 0), true);
        
        // Get next Monday
        Date today = Date.today();
        Date nextMonday = today.toStartOfWeek();
        Datetime dt = Datetime.newInstance(nextMonday.year(), nextMonday.month(), nextMonday.day());
        if (dt.format('EEEE') == 'Sunday') {
            nextMonday = nextMonday.addDays(1);
        } else if (dt.format('EEEE') != 'Monday') {
            // Should be handled to find Monday
            while(Datetime.newInstance(nextMonday.year(), nextMonday.month(), nextMonday.day()).format('EEEE') != 'Monday') {
                nextMonday = nextMonday.addDays(1);
            }
        }
        
        // Holiday on Monday
        AA_Branch_Holiday__c holiday = new AA_Branch_Holiday__c(
            Business_Branch__c = branch.Id,
            Date__c = nextMonday,
            Name = 'Test Holiday'
        );
        insert holiday;
        
        AA_Service_Category__c category = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c service = AA_TestDataFactory.createService(branch.Id, category.Id, true);
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(business.Id, true);
        
        // Appointment on Monday at 10:00 AM
        AA_Appointment__c appt = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = employee.Id,
            Service__c = service.Id,
            Start_Date_Time__c = Datetime.newInstance(nextMonday.year(), nextMonday.month(), nextMonday.day(), 10, 0, 0).addHours(3), // GMT-3 offset
            Status__c = 'Pending'
        );
        insert appt;
        
        // Absence on Monday at 11:00 AM
        AA_Employee_Absence__c absence = new AA_Employee_Absence__c(
            Employee__c = employee.Id,
            Start_Date_Time__c = Datetime.newInstance(nextMonday.year(), nextMonday.month(), nextMonday.day(), 11, 0, 0).addHours(3),
            End_Date_Time__c = Datetime.newInstance(nextMonday.year(), nextMonday.month(), nextMonday.day(), 12, 0, 0).addHours(3),
            Category__c = 'Break'
        );
        insert absence;
    }
    
    @IsTest
    static void testGetWeeklyOccupancy() {
        Date today = Date.today();
        Date nextMonday = today.toStartOfWeek();
        while(Datetime.newInstance(nextMonday.year(), nextMonday.month(), nextMonday.day()).format('EEEE') != 'Monday') {
            nextMonday = nextMonday.addDays(1);
        }
        
        User adminUser = [SELECT Id FROM User WHERE LastName = 'Admin' LIMIT 1];
        
        Test.startTest();
        AA_WeeklyMatrixController.WeeklyMatrixResponse response;
        System.runAs(adminUser) {
            response = AA_WeeklyMatrixController.getWeeklyOccupancy(nextMonday);
        }
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(1, response.holidays.size(), 'Should have 1 holiday');
        System.assertNotEquals(null, response.branchHours, 'Branch hours should be populated');
        System.assertNotEquals(null, response.matrix, 'Matrix should be populated');
        System.assert(response.timeSlots.size() > 0, 'Should have time slots');
    }
    
    @IsTest
    static void testExceptions() {
        // Run as standard user (no employee)
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
                AA_WeeklyMatrixController.getWeeklyOccupancy(Date.today());
                System.assert(false, 'Should throw exception for no employee');
            } catch (Exception e) {
                System.assertEquals('System.AuraHandledException', e.getTypeName(), 'Expected AuraHandledException');
            }
        }
        
        // Update employee to inactive
        User adminUser = [SELECT Id, AA_Is_Employee_Admin__c FROM User WHERE LastName = 'Admin' LIMIT 1];
        AA_Employee__c emp = [SELECT Id, User__c FROM AA_Employee__c WHERE User__c = :adminUser.Id LIMIT 1];
        
        // Fix for validation rule: cannot deactivate employee with pending appointments
        List<AA_Appointment__c> appts = [SELECT Id FROM AA_Appointment__c WHERE Employee__c = :emp.Id];
        for (AA_Appointment__c a : appts) {
            a.Status__c = 'Done';
        }
        update appts;
        
        emp.Is_Active__c = false;
        update emp;
        
        System.runAs(adminUser) {
            try {
                AA_WeeklyMatrixController.getWeeklyOccupancy(Date.today());
                System.assert(false, 'Should throw exception for inactive employee');
            } catch (Exception e) {
                System.assertEquals('System.AuraHandledException', e.getTypeName(), 'Expected AuraHandledException');
            }
        }
        
        // Update employee to active but non-admin
        emp.Is_Active__c = true;
        update emp;
        
        adminUser.AA_Is_Employee_Admin__c = false;
        update adminUser;
        
        System.runAs(adminUser) {
            try {
                AA_WeeklyMatrixController.getWeeklyOccupancy(Date.today());
                System.assert(false, 'Should throw exception for non-admin employee');
            } catch (Exception e) {
                System.assertEquals('System.AuraHandledException', e.getTypeName(), 'Expected AuraHandledException');
            }
        }
        
        Test.stopTest();
    }
}
