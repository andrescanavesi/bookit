@IsTest
private class AA_SalonAppointmentsControllerTest {

    @testSetup
    static void setupTestData() {
        AA_Business__c business = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(business.Id, true);
        AA_Employee__c emp = AA_TestDataFactory.createEmployee(branch.Id, UserInfo.getUserId(), true);
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(business.Id, true);
        AA_Service_Category__c category = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c service = AA_TestDataFactory.createService(branch.Id, category.Id, true);
        AA_Employee_Service__c empService = AA_TestDataFactory.createEmployeeService(emp.Id, service.Id, true);
        AA_Appointment__c appt = AA_TestDataFactory.createAppointment(customer.Id, emp.Id, service.Id, System.now().addDays(1), true);
    }

    @isTest
    static void testGetSalonAppointments() {
        Test.startTest();
        AA_SalonAppointmentsController.AgendaContext context = AA_SalonAppointmentsController.getSalonAppointments();
        Test.stopTest();
        
        System.assertNotEquals(null, context, 'Context should not be null');
        System.assertNotEquals(null, context.isAdmin, 'IsAdmin should be populated');
        System.assert(context.appointments.size() >= 0, 'Should return appointments list');
    }

    @isTest
    static void testMarkReminderAsSent() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.markReminderAsSent(appt.Id);
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Reminder_Sent_Date__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertNotEquals(null, updatedAppt.Reminder_Sent_Date__c, 'Reminder date should be set');
    }

    @isTest
    static void testConfirmAppointment() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.confirmAppointment(appt.Id, 'Test Comments');
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Status__c, Internal_Comments__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Confirmed', updatedAppt.Status__c, 'Status should be Confirmed');
        System.assertEquals('Test Comments', updatedAppt.Internal_Comments__c, 'Comments should match');
    }

    @isTest
    static void testCancelAppointment() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.cancelAppointment(appt.Id, 'Cancel Comments');
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Status__c, Cancelled_Date__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Cancelled', updatedAppt.Status__c, 'Status should be Cancelled');
        System.assertNotEquals(null, updatedAppt.Cancelled_Date__c, 'Cancelled date should be set');
    }

    @isTest
    static void testSetNoShowAppointment() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.setNoShowAppointment(appt.Id);
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Status__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('No Show', updatedAppt.Status__c, 'Status should be No Show');
    }

    @isTest
    static void testCompleteAppointment() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.completeAppointment(appt.Id, 'Done', 'Efectivo', 50.0);
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Status__c, Payment_Method__c, Payment_Amount__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Done', updatedAppt.Status__c, 'Status should be Done');
        System.assertEquals('Efectivo', updatedAppt.Payment_Method__c, 'Payment method should be Efectivo');
        System.assertEquals(50.0, updatedAppt.Payment_Amount__c, 'Payment amount should be 50.0');
    }

    @isTest
    static void testGetMatrixData() {
        Date tomorrow = System.today().addDays(1);
        
        Test.startTest();
        AA_SalonAppointmentsController.MatrixDataWrapper wrapper = AA_SalonAppointmentsController.getMatrixData(tomorrow);
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assert(wrapper.employees.size() > 0, 'Should have employees');
        System.assert(wrapper.allServices.size() > 0, 'Should have services');
        System.assert(wrapper.allCustomers.size() > 0, 'Should have customers');
    }

    @isTest
    static void testCreateNewAppointment() {
        AA_Customer__c customer = [SELECT Id FROM AA_Customer__c LIMIT 1];
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        AA_Service__c service = [SELECT Id FROM AA_Service__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.createNewAppointment(customer.Id, emp.Id, service.Id, System.now().addDays(2));
        Test.stopTest();
        
        List<AA_Appointment__c> appts = [SELECT Id FROM AA_Appointment__c];
        System.assertEquals(2, appts.size(), 'Should have two appointments now');
    }

    @isTest
    static void testAbsenceOperations() {
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.createAbsence(emp.Id, System.now(), 60, 'Break');
        List<AA_Employee_Absence__c> absences = [SELECT Id FROM AA_Employee_Absence__c];
        System.assertEquals(1, absences.size(), 'Should have one absence');
        
        AA_SalonAppointmentsController.deleteAbsence(absences[0].Id);
        Test.stopTest();
        
        absences = [SELECT Id FROM AA_Employee_Absence__c];
        System.assertEquals(0, absences.size(), 'Absence should be deleted');
    }

    @isTest
    static void testGetWeekHolidays() {
        AA_Business_Branch__c branch = [SELECT Id, Business__c FROM AA_Business_Branch__c LIMIT 1];
        
        AA_Branch_Holiday__c holiday = new AA_Branch_Holiday__c(
            Name = 'Test Holiday',
            Business_Branch__c = branch.Id,
            Date__c = System.today()
        );
        insert holiday;
        
        Test.startTest();
        List<AA_Branch_Holiday__c> holidays = AA_SalonAppointmentsController.getWeekHolidays(System.today());
        Test.stopTest();
        
        System.assertEquals(1, holidays.size(), 'Should return the holiday');
    }

    @isTest
    static void testReassignAppointment() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        // Create another employee
        AA_Business_Branch__c branch = [SELECT Id FROM AA_Business_Branch__c LIMIT 1];
        AA_Employee__c newEmp = AA_TestDataFactory.createEmployee(branch.Id, null, true);
        
        Test.startTest();
        AA_SalonAppointmentsController.reassignAppointment(appt.Id, newEmp.Id);
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Employee__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals(newEmp.Id, updatedAppt.Employee__c, 'Employee should be reassigned');
    }
    
    @isTest
    static void testGetEmployeesAndCustomers() {
        Test.startTest();
        List<AA_Employee__c> emps = AA_SalonAppointmentsController.getEmployees();
        List<AA_Customer__c> customers = AA_SalonAppointmentsController.getCustomers();
        Test.stopTest();
        
        System.assert(emps.size() > 0, 'Should return employees');
        System.assert(customers.size() > 0, 'Should return customers');
    }
    
    @isTest
    static void testMarkBookConfirmationAsSent() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.markBookConfirmationAsSent(appt.Id);
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Book_Confirmation_Sent_Date__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertNotEquals(null, updatedAppt.Book_Confirmation_Sent_Date__c, 'Confirmation date should be set');
    }
    
    @isTest
    static void testMarkAsPaid() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.markAsPaid(appt.Id);
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Payment_Date__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals(System.today(), updatedAppt.Payment_Date__c, 'Payment date should be today');
    }

    @isTest
    static void testUpdateAppointmentWithValidation() {
        AA_Appointment__c appt = [SELECT Id, Employee__c, Start_Date_Time__c FROM AA_Appointment__c LIMIT 1];
        
        Test.startTest();
        AA_SalonAppointmentsController.updateAppointmentWithValidation(
            appt.Id, 
            appt.Employee__c, 
            appt.Start_Date_Time__c, 
            'Nuevos Comentarios Test'
        );
        Test.stopTest();
        
        AA_Appointment__c updatedAppt = [SELECT Internal_Comments__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Nuevos Comentarios Test', updatedAppt.Internal_Comments__c, 'Comments should be updated');
    }
}
