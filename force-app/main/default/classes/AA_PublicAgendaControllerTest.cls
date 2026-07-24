@IsTest
private class AA_PublicAgendaControllerTest {
    
    @testSetup
    static void setupTestData() {
        AA_Business__c business = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(business.Id, true);
        AA_Service_Category__c cat = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c service = AA_TestDataFactory.createService(branch.Id, cat.Id, true);
        AA_Employee__c emp = AA_TestDataFactory.createEmployee(branch.Id, UserInfo.getUserId(), true);
        AA_Employee_Working_Hour__c ewh = AA_TestDataFactory.createWorkingHour(emp.Id, 'Monday', Time.newInstance(9, 0, 0, 0), Time.newInstance(18, 0, 0, 0), true);
        AA_Employee_Service__c empServ = AA_TestDataFactory.createEmployeeService(emp.Id, service.Id, true);
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(business.Id, true);
    }
    
    @IsTest
    static void testGetOrCreateCustomer_Existing() {
        AA_Business__c business = [SELECT Id FROM AA_Business__c LIMIT 1];
        AA_Customer__c existingCust = [SELECT Phone_Number__c FROM AA_Customer__c LIMIT 1];
        
        Test.startTest();
        AA_Customer__c result = AA_PublicAgendaController.getOrCreateCustomer(existingCust.Phone_Number__c, business.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return existing customer');
        System.assertEquals(existingCust.Phone_Number__c, result.Phone_Number__c, 'Phone number should match');
    }
    
    @IsTest
    static void testGetOrCreateCustomer_New() {
        AA_Business__c business = [SELECT Id FROM AA_Business__c LIMIT 1];
        String newPhone = '099999999';
        
        Test.startTest();
        AA_Customer__c result = AA_PublicAgendaController.getOrCreateCustomer(newPhone, business.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return new customer');
        System.assertEquals('59899999999', result.Phone_Number__c, 'Phone number should be normalized');
    }
    
    @IsTest
    static void testUpdateCustomer() {
        AA_Customer__c existingCust = [SELECT Id FROM AA_Customer__c LIMIT 1];
        
        Test.startTest();
        AA_Customer__c result = AA_PublicAgendaController.updateCustomer(existingCust.Id, 'Juan', 'Perez', 'juan@test.com', 'Comentarios', true);
        Test.stopTest();
        
        System.assertEquals('Juan', result.First_Name__c, 'First name should be updated');
        System.assertEquals('Perez', result.Last_Name__c, 'Last name should be updated');
        System.assertEquals('juan@test.com', result.Email__c, 'Email should be updated');
    }
    
    @IsTest
    static void testUpdateCustomer_Error() {
        Test.startTest();
        try {
            // Passing fake ID to trigger error
            AA_PublicAgendaController.updateCustomer('001000000000000', 'Juan', 'Perez', 'juan@test.com', 'Comentarios', true);
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetBusinessInfo() {
        AA_Business__c business = [SELECT Id FROM AA_Business__c LIMIT 1];
        
        Test.startTest();
        Map<String, String> info = AA_PublicAgendaController.getBusinessInfo(business.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, info, 'Should return business info');
        System.assert(info.containsKey('Branch_Name'), 'Should contain branch name');
    }
    
    @IsTest
    static void testGetBusinessInfo_NotFound() {
        // Create fake business ID
        Id fakeId = 'a06000000000000';
        Test.startTest();
        Map<String, String> info = AA_PublicAgendaController.getBusinessInfo(fakeId);
        Test.stopTest();
        
        System.assertEquals(null, info, 'Should return null for non-existing business');
    }
    
    @IsTest
    static void testGetCategories() {
        AA_Business__c business = [SELECT Id FROM AA_Business__c LIMIT 1];
        
        Test.startTest();
        List<AA_Service_Category__c> categories = AA_PublicAgendaController.getCategories(business.Id);
        Test.stopTest();
        
        System.assertNotEquals(0, categories.size(), 'Should return categories');
    }
    
    @IsTest
    static void testGetServices() {
        AA_Business__c business = [SELECT Id FROM AA_Business__c LIMIT 1];
        
        Test.startTest();
        List<AA_Service__c> services = AA_PublicAgendaController.getServices(business.Id);
        Test.stopTest();
        
        System.assertNotEquals(0, services.size(), 'Should return services');
    }
    
    @IsTest
    static void testGetAvailableSlots() {
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        // Find next monday
        Date targetDate = Date.today();
        while (DateTime.newInstance(targetDate, Time.newInstance(0,0,0,0)).format('EEEE') != 'Monday') {
            targetDate = targetDate.addDays(1);
        }
        String dateStr = String.valueOf(targetDate);
        
        Test.startTest();
        List<AA_AvailableSlot> slots = AA_PublicAgendaController.getAvailableSlots(service.Id, dateStr);
        Test.stopTest();
        
        System.assertNotEquals(null, slots, 'Should return slots list');
    }
    
    @IsTest
    static void testSaveAppointment() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Date targetDate = Date.today();
        while (DateTime.newInstance(targetDate, Time.newInstance(0,0,0,0)).format('EEEE') != 'Monday') {
            targetDate = targetDate.addDays(1);
        }
        
        Test.startTest();
        AA_Appointment__c appt = AA_PublicAgendaController.saveAppointment(customer.Id, emp.Id, service.Id, String.valueOf(targetDate), '10:00');
        Test.stopTest();
        
        System.assertNotEquals(null, appt.Id, 'Appointment should be saved');
    }
    
    @IsTest
    static void testSaveAppointment_Error() {
        Test.startTest();
        try {
            AA_PublicAgendaController.saveAppointment(null, null, null, 'invalid', 'invalid');
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetMisTurnos() {
        AA_Business__c business = [SELECT Id FROM AA_Business__c LIMIT 1];
        AA_Customer__c customer = [SELECT Id, Phone_Number__c FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Date targetDate = Date.today().addDays(1);
        AA_Appointment__c appt = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = emp.Id,
            Service__c = service.Id,
            Start_Date_Time__c = DateTime.newInstance(targetDate, Time.newInstance(10, 0, 0, 0)),
            Status__c = 'Pending'
        );
        insert appt;
        
        Test.startTest();
        List<AA_Appointment__c> turnos = AA_PublicAgendaController.getMisTurnos(customer.Phone_Number__c, business.Id);
        Test.stopTest();
        
        System.assertNotEquals(0, turnos.size(), 'Should return appointments');
    }
    
    @IsTest
    static void testCancelarAppointment() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Date targetDate = Date.today().addDays(1);
        AA_Appointment__c appt = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = emp.Id,
            Service__c = service.Id,
            Start_Date_Time__c = DateTime.newInstance(targetDate, Time.newInstance(10, 0, 0, 0)),
            Status__c = 'Pending'
        );
        insert appt;
        
        Test.startTest();
        AA_PublicAgendaController.cancelarAppointment(appt.Id);
        Test.stopTest();
        
        AA_Appointment__c cancelledAppt = [SELECT Status__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Cancelled', cancelledAppt.Status__c, 'Status should be cancelled');
    }
    
    @IsTest
    static void testConfirmarAsistencia() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Date targetDate = Date.today().addDays(1);
        AA_Appointment__c appt = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = emp.Id,
            Service__c = service.Id,
            Start_Date_Time__c = DateTime.newInstance(targetDate, Time.newInstance(10, 0, 0, 0)),
            Status__c = 'Pending'
        );
        insert appt;
        
        Test.startTest();
        AA_PublicAgendaController.confirmarAsistencia(appt.Id);
        Test.stopTest();
        
        AA_Appointment__c confirmedAppt = [SELECT Customer_Confirmation_Date__c, Internal_Comments__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertNotEquals(null, confirmedAppt.Customer_Confirmation_Date__c, 'Confirmation date should be set');
        System.assert(confirmedAppt.Internal_Comments__c.contains('Confirmado por el cliente'), 'Comment should be added');
    }
    
    @IsTest
    static void testRecoordinarAppointment() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Date targetDate = Date.today();
        while (DateTime.newInstance(targetDate, Time.newInstance(0,0,0,0)).format('EEEE') != 'Monday') {
            targetDate = targetDate.addDays(1);
        }
        
        AA_Appointment__c oldAppt = new AA_Appointment__c(
            Customer__c = customer.Id,
            Employee__c = emp.Id,
            Service__c = service.Id,
            Start_Date_Time__c = DateTime.newInstance(targetDate, Time.newInstance(10, 0, 0, 0)),
            Status__c = 'Pending'
        );
        insert oldAppt;
        
        Test.startTest();
        AA_Appointment__c newAppt = AA_PublicAgendaController.recoordinarAppointment(oldAppt.Id, customer.Id, emp.Id, service.Id, String.valueOf(targetDate), '11:00');
        Test.stopTest();
        
        System.assertNotEquals(null, newAppt, 'New appointment should be returned');
        AA_Appointment__c oldApptUpdated = [SELECT Status__c FROM AA_Appointment__c WHERE Id = :oldAppt.Id];
        System.assertEquals('Cancelled', oldApptUpdated.Status__c, 'Old appointment should be cancelled');
    }
    
    @IsTest
    static void testGetComboSlots() {
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        List<Id> serviceIds = new List<Id>{service.Id};
        
        Date targetDate = Date.today();
        while (DateTime.newInstance(targetDate, Time.newInstance(0,0,0,0)).format('EEEE') != 'Monday') {
            targetDate = targetDate.addDays(1);
        }
        
        Test.startTest();
        List<AA_ComboSlot> combos = AA_PublicAgendaController.getComboSlots(serviceIds, String.valueOf(targetDate));
        Test.stopTest();
        
        System.assertNotEquals(null, combos, 'Should return combo slots');
    }
    
    @IsTest
    static void testSaveComboAppointments() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Date targetDate = Date.today();
        while (DateTime.newInstance(targetDate, Time.newInstance(0,0,0,0)).format('EEEE') != 'Monday') {
            targetDate = targetDate.addDays(1);
        }
        String dateStr = String.valueOf(targetDate);
        
        String jsonCombo = '{"slots":[{"employeeId":"' + emp.Id + '","serviceId":"' + service.Id + '","slotDayString":"' + dateStr + '","slotTimeString":"10:00"}]}';
        
        Test.startTest();
        List<AA_Appointment__c> appts = AA_PublicAgendaController.saveComboAppointments(customer.Id, jsonCombo, 'Efectivo');
        Test.stopTest();
        
        System.assertEquals(1, appts.size(), 'Should save one appointment');
    }
    
    @IsTest
    static void testSaveComboAppointments_TwoSlots() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Date targetDate = Date.today();
        while (DateTime.newInstance(targetDate, Time.newInstance(0,0,0,0)).format('EEEE') != 'Monday') {
            targetDate = targetDate.addDays(1);
        }
        String dateStr = String.valueOf(targetDate);
        
        String jsonCombo = '{"slots":[' +
            '{"employeeId":"' + emp.Id + '","serviceId":"' + service.Id + '","slotDayString":"' + dateStr + '","slotTimeString":"10:00"},' +
            '{"employeeId":"' + emp.Id + '","serviceId":"' + service.Id + '","slotDayString":"' + dateStr + '","slotTimeString":"10:30"}' +
        ']}';
        
        Test.startTest();
        List<AA_Appointment__c> appts = AA_PublicAgendaController.saveComboAppointments(customer.Id, jsonCombo, 'Efectivo');
        Test.stopTest();
        
        System.assertEquals(2, appts.size(), 'Should save two appointments');
        
        AA_Appointment__c appt2 = [SELECT Internal_Comments__c FROM AA_Appointment__c WHERE Id = :appts[1].Id];
        System.assert(appt2.Internal_Comments__c.contains('Agendado junto a la cita'), 'Should have linked comment');
    }
}
