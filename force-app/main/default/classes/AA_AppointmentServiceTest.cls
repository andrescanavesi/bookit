@IsTest
private class AA_AppointmentServiceTest {
    
    @TestSetup
    static void setup() {
        AA_Business__c biz = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(biz.Id, true);
        
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User adminUser = new User(
            Alias = 'adminTst',
            Email = 'adminTst@bookit.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AdminTestApptSvc',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Montevideo',
            UserName = 'adminTestApptSvc' + Crypto.getRandomInteger() + '@bookit.com',
            AA_Is_Employee_Admin__c = true
        );
        insert adminUser;
        
        AA_Employee__c emp = AA_TestDataFactory.createEmployee(branch.Id, adminUser.Id, false);
        emp.Available_In_Public_Agenda__c = true;
        insert emp;
        
        // Horarios para el emp (lunes a domingo de 9 a 18)
        List<String> days = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'};
        List<AA_Employee_Working_Hour__c> whList = new List<AA_Employee_Working_Hour__c>();
        for (String day : days) {
            AA_Employee_Working_Hour__c wh = AA_TestDataFactory.createWorkingHour(
                emp.Id, day, 
                Time.newInstance(9, 0, 0, 0), 
                Time.newInstance(18, 0, 0, 0), 
                false
            );
            whList.add(wh);
        }
        insert whList;
        
        AA_Service_Category__c category = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c svc1 = AA_TestDataFactory.createService(branch.Id, category.Id, false);
        svc1.Duration_Minutes__c = 60;
        insert svc1;
        
        AA_Service__c svc2 = AA_TestDataFactory.createService(branch.Id, category.Id, false);
        svc2.Duration_Minutes__c = 30;
        insert svc2;
        
        AA_Employee_Service__c empSvc1 = AA_TestDataFactory.createEmployeeService(emp.Id, svc1.Id, true);
        AA_Employee_Service__c empSvc2 = AA_TestDataFactory.createEmployeeService(emp.Id, svc2.Id, true);
        
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(biz.Id, true);
    }
    
    @IsTest
    static void testGetAvailableSlotsSingleDay() {
        AA_Service__c svc = [SELECT Id FROM AA_Service__c LIMIT 1];
        Date targetDate = Date.today().addDays(7); // Proxima semana
        
        Test.startTest();
        List<AA_AvailableSlot> slots = AA_AppointmentService.getAvailableSlots(svc.Id, targetDate);
        Test.stopTest();
        
        System.assert(slots != null, 'Slots should not be null');
        System.assert(!slots.isEmpty(), 'There should be slots available');
    }
    
    @IsTest
    static void testGetAvailableSlotsDateRange() {
        AA_Service__c svc = [SELECT Id FROM AA_Service__c LIMIT 1];
        Date targetDateStart = Date.today().addDays(7);
        Date targetDateEnd = Date.today().addDays(9);
        
        Test.startTest();
        List<AA_AvailableSlot> slots = AA_AppointmentService.getAvailableSlots(svc.Id, targetDateStart, targetDateEnd);
        Test.stopTest();
        
        System.assert(slots != null, 'Slots should not be null');
        System.assert(!slots.isEmpty(), 'There should be slots available for range');
    }
    
    @IsTest
    static void testSaveAppointment() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c svc = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        String dayString = '2023-10-15';
        String timeString = '10:00';
        
        Test.startTest();
        AA_Appointment__c appt = AA_AppointmentService.saveAppointment(customer.Id, emp.Id, svc.Id, dayString, timeString);
        AA_Appointment__c appt2 = AA_AppointmentService.saveAppointment(customer.Id, emp.Id, svc.Id, dayString, '11:00', 'Efectivo');
        Test.stopTest();
        
        System.assert(appt != null && appt.Id != null, 'Appointment 1 should be created');
        System.assert(appt2 != null && appt2.Id != null, 'Appointment 2 should be created');
        System.assertEquals('Efectivo', appt2.Payment_Method__c, 'Payment method should match');
    }
    
    @IsTest
    static void testGetComboAvailableSlots() {
        List<AA_Service__c> services = [SELECT Id FROM AA_Service__c LIMIT 2];
        List<Id> serviceIds = new List<Id>();
        for (AA_Service__c svc : services) {
            serviceIds.add(svc.Id);
        }
        
        Date targetDate = Date.today().addDays(7);
        
        Test.startTest();
        List<AA_ComboSlot> comboSlots1 = AA_AppointmentService.getComboAvailableSlots(new List<Id>{serviceIds[0]}, targetDate);
        List<AA_ComboSlot> comboSlots2 = AA_AppointmentService.getComboAvailableSlots(serviceIds, targetDate);
        List<AA_ComboSlot> comboSlotsEmpty = AA_AppointmentService.getComboAvailableSlots(new List<Id>(), targetDate);
        Test.stopTest();
        
        System.assert(comboSlots1 != null, 'Combo slots for 1 service should not be null');
        System.assert(comboSlots2 != null, 'Combo slots for 2 services should not be null');
        System.assert(comboSlotsEmpty.isEmpty(), 'Combo slots for 0 services should be empty');
    }
}
