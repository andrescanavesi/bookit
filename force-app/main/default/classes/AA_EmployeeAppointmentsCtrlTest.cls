@IsTest
private class AA_EmployeeAppointmentsCtrlTest {
    
    @TestSetup
    static void setupData() {
        AA_Business__c business = AA_TestDataFactory.createBusiness(true);
        AA_Business_Branch__c branch = AA_TestDataFactory.createBranch(business.Id, true);
        
        // Create employee
        AA_Employee__c emp = AA_TestDataFactory.createEmployee(branch.Id, UserInfo.getUserId(), false);
        emp.Is_Active__c = true;
        insert emp;
        
        // Create service category and service
        AA_Service_Category__c cat = AA_TestDataFactory.createServiceCategory(branch.Id, true);
        AA_Service__c service = AA_TestDataFactory.createService(branch.Id, cat.Id, true);
        
        // Create customer
        AA_Customer__c customer = AA_TestDataFactory.createCustomer(business.Id, false);
        customer.Has_Allergy_Esmalte_Semipermanente__c = true;
        customer.Comments_From_Customer__c = 'Likes coffee';
        customer.Internal_Comments__c = 'VIP';
        insert customer;
        
        // Create appointment
        AA_Appointment__c appt = AA_TestDataFactory.createAppointment(customer.Id, emp.Id, service.Id, DateTime.now().addHours(1), false);
        appt.Status__c = 'Pending';
        appt.Customer_Comments__c = 'Late 5 mins';
        appt.Internal_Comments__c = 'Needs extra care';
        insert appt;
    }
    
    @IsTest
    static void testGetEmployees() {
        Test.startTest();
        List<AA_Employee__c> emps = AA_EmployeeAppointmentsCtrl.getEmployees();
        Test.stopTest();
        
        System.assertNotEquals(0, emps.size(), 'Should return active employees for the branch.');
    }
    
    @IsTest
    static void testGetPendingAppointments() {
        AA_Employee__c emp = [SELECT Id FROM AA_Employee__c LIMIT 1];
        
        Test.startTest();
        List<AA_EmployeeAppointmentsCtrl.AppointmentDTO> appts = AA_EmployeeAppointmentsCtrl.getPendingAppointments(emp.Id, Date.today());
        Test.stopTest();
        
        System.assertEquals(1, appts.size(), 'Should return 1 pending appointment for today.');
        System.assertEquals('Pending', appts[0].appt.Status__c, 'Status should be Pending.');
    }
    
    @IsTest
    static void testSaveAppointmentDetails() {
        AA_Appointment__c appt = [SELECT Id FROM AA_Appointment__c LIMIT 1];
        AA_Customer__c cust = [SELECT Id FROM AA_Customer__c LIMIT 1];
        
        Map<String, Object> apptData = new Map<String, Object>{
            'Id' => appt.Id,
            'Status__c' => 'Done',
            'Payment_Method__c' => 'Efectivo',
            'Payment_Amount__c' => '1000',
            'Customer_Comments__c' => 'Updated Appt Comments',
            'Internal_Comments__c' => 'Updated Appt Internal'
        };
        
        Map<String, Object> custData = new Map<String, Object>{
            'Id' => cust.Id,
            'Comments_From_Customer__c' => 'Updated Cust Comments',
            'Internal_Comments__c' => 'Updated Cust Internal'
        };
        
        Test.startTest();
        AA_EmployeeAppointmentsCtrl.saveAppointmentDetails(apptData, custData);
        Test.stopTest();
        
        // Verify updates
        AA_Appointment__c updatedAppt = [SELECT Status__c, Payment_Method__c, Payment_Amount__c, Customer_Comments__c, Internal_Comments__c FROM AA_Appointment__c WHERE Id = :appt.Id];
        AA_Customer__c updatedCust = [SELECT Comments_From_Customer__c, Internal_Comments__c FROM AA_Customer__c WHERE Id = :cust.Id];
        
        System.assertEquals('Done', updatedAppt.Status__c, 'Status should be updated to Done');
        System.assertEquals('Efectivo', updatedAppt.Payment_Method__c, 'Payment method should be updated');
        System.assertEquals(1000, updatedAppt.Payment_Amount__c, 'Payment amount should be updated');
        System.assertEquals('Updated Appt Comments', updatedAppt.Customer_Comments__c, 'Appointment comments should be updated');
        System.assertEquals('Updated Cust Comments', updatedCust.Comments_From_Customer__c, 'Customer comments should be updated');
    }
}
