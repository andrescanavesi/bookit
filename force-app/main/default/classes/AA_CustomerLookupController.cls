public with sharing class AA_CustomerLookupController {
    
    private static Id getBusinessId() {
        List<AA_Employee__c> employees = [SELECT Id, Business_Id__c FROM AA_Employee__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
        if (employees.isEmpty()) {
            throw new AuraHandledException('El empleado no está configurado como usuario.');
        }
        return employees[0].Business_Id__c;
    }

    @AuraEnabled(cacheable=true)
    public static List<AA_Customer__c> searchCustomers(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 3) {
            return new List<AA_Customer__c>();
        }
        
        Id businessId = getBusinessId();
        String likeTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        
        return [
            SELECT Id, First_Name__c, Last_Name__c, Phone_Number__c 
            FROM AA_Customer__c 
            WHERE Business__c = :businessId
              AND (First_Name__c LIKE :likeTerm 
               OR Last_Name__c LIKE :likeTerm 
               OR Phone_Number__c LIKE :likeTerm)
            ORDER BY LastModifiedDate DESC
            LIMIT 15
        ];
    }

    @AuraEnabled
    public static AA_Customer__c createCustomer(String firstName, String lastName, String phone) {
        AA_Logger logger = new AA_Logger(true);
        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            throw new AuraHandledException('El nombre y el apellido son obligatorios.');
        }
        
        Id businessId = getBusinessId();
        
        // Validación de duplicados por celular en el mismo salón
        if (String.isNotBlank(phone)) {
            List<AA_Customer__c> existingCustomers = [
                SELECT Id FROM AA_Customer__c 
                WHERE Phone_Number__c = :phone 
                  AND Business__c = :businessId 
                LIMIT 1
            ];
            
            if (!existingCustomers.isEmpty()) {
                String message = 'Ya existe una persona con este número de celular '+phone+' en tu salón '+businessId;
                logger.info(message);
                throw new AuraHandledException(message);
            }
        }
        
        AA_Customer__c newCustomer = new AA_Customer__c(
            First_Name__c = firstName,
            Last_Name__c = lastName,
            Name = firstName + ' ' + lastName, // Asumiendo que Name es un autonumber o string, pero si es texto lo poblamos
            Phone_Number__c = phone,
            Business__c = businessId
        );
        
        insert newCustomer;
        return newCustomer;
    }
}