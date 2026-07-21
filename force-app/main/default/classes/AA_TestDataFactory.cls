@IsTest(isParallel=true)
public class AA_TestDataFactory {
    
    private static String getRandomString() {
        return String.valueOf(Crypto.getRandomInteger());
    }

    public static AA_Business__c createBusiness(Boolean doInsert) {
        AA_Business__c biz = new AA_Business__c(Name = 'Business ' + getRandomString());
        if (doInsert) insert biz;
        return biz;
    }
    
    public static AA_Business_Branch__c createBranch(Id businessId, Boolean doInsert) {
        String branchName = 'Branch ' + getRandomString();
        AA_Business_Branch__c branch = new AA_Business_Branch__c(
            Name = branchName,
            Display_Name__c = branchName,
            Business__c = businessId
        );
        if (doInsert) insert branch;
        return branch;
    }
    
    public static AA_Employee__c createEmployee(Id branchId, Id userId, Boolean doInsert) {
        AA_Employee__c emp = new AA_Employee__c(
            First_Name__c = 'Emp' + getRandomString(),
            Last_Name__c = 'Test',
            Business_Branch__c = branchId,
            User__c = userId,
            Is_Active__c = true,
            Color__c = '#FFFFFF'
        );
        if (doInsert) insert emp;
        return emp;
    }
    
    public static AA_Customer__c createCustomer(Id businessId, Boolean doInsert) {
        AA_Customer__c customer = new AA_Customer__c(
            First_Name__c = 'Cust' + getRandomString(),
            Last_Name__c = 'Test',
            Phone_Number__c = '123' + Math.abs(Crypto.getRandomInteger()).format().replaceAll(',', '').right(7),
            Business__c = businessId
        );
        if (doInsert) insert customer;
        return customer;
    }
    
    public static AA_Service_Category__c createServiceCategory(Id branchId, Boolean doInsert) {
        String catName = 'Cat ' + getRandomString();
        AA_Service_Category__c category = new AA_Service_Category__c(
            Name = catName,
            Display_Name__c = catName,
            Business_Branch__c = branchId
        );
        if (doInsert) insert category;
        return category;
    }
    
    public static AA_Service__c createService(Id branchId, Id categoryId, Boolean doInsert) {
        String srvName = 'Srv ' + getRandomString();
        AA_Service__c service = new AA_Service__c(
            Name = srvName,
            Display_Name__c = srvName,
            Duration_Minutes__c = 30,
            Price__c = 50,
            Business_Branch__c = branchId,
            AA_Service_Category__c = categoryId,
            Is_Active__c = true
        );
        if (doInsert) insert service;
        return service;
    }
    
    public static AA_Appointment__c createAppointment(Id customerId, Id employeeId, Id serviceId, Datetime startDateTime, Boolean doInsert) {
        AA_Appointment__c appt = new AA_Appointment__c(
            Customer__c = customerId,
            Employee__c = employeeId,
            Service__c = serviceId,
            Start_Date_Time__c = startDateTime,
            Status__c = 'Pending'
        );
        if (doInsert) insert appt;
        return appt;
    }
    
    public static AA_Employee_Service__c createEmployeeService(Id employeeId, Id serviceId, Boolean doInsert) {
        AA_Employee_Service__c empSvc = new AA_Employee_Service__c(
            Employee__c = employeeId,
            Service__c = serviceId
        );
        if (doInsert) insert empSvc;
        return empSvc;
    }
    public static AA_Employee_Working_Hour__c createWorkingHour(Id employeeId, String dayOfWeek, Time startTime, Time endTime, Boolean doInsert) {
        AA_Employee_Working_Hour__c ewh = new AA_Employee_Working_Hour__c(
            Employee__c = employeeId,
            Day_of_Week__c = dayOfWeek,
            Start_Hour__c = startTime,
            End_Hour__c = endTime
        );
        if (doInsert) insert ewh;
        return ewh;
    }
}
