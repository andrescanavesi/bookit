public without sharing class AA_PublicAgendaController {
    
    private static Id BRANCH_ID = 'a03gL00000YGsWJQA1'; 
    
    @AuraEnabled(cacheable=false)
    public static AA_Customer__c getOrCreateCustomer(String phoneNumber){
        AA_Logger logger = new AA_Logger(true);
        logger.info('getOrCreateCustomer, phoneNumber '+phoneNumber);
        // TODO for now we assume we have only one business
        AA_Business__c  business = getBusiness();
        //String fullName = 'guest'; 
        
        List<AA_Customer__c> customers = [SELECT Id, Name, Email__c, Phone_Number__c, Business__r.Business_Phone_Id__c  
                                          FROM AA_Customer__c 
                                          WHERE Phone_Number__c = :phoneNumber LIMIT 1];
        if(!customers.isEmpty()){
            logger.info('getOrCreateCustomer, customer found by found number '+phoneNumber);
            return customers.get(0);
        }else{
            logger.info('getOrCreateCustomer, a new customer will be created with the phone '+phoneNumber);
            AA_Customer__c customer = new AA_Customer__c();
            customer.Name  = phoneNumber;
            customer.Phone_Number__c = phoneNumber;
            customer.Business__c = business.Id;
            insert customer;
            return customer;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static AA_Customer__c updateCustomer(String customerId, String fullName, String email){
        AA_Logger logger = new AA_Logger(true);
        logger.info('updateCustomer, customerId '+customerId+ ' fullName: '+fullName+' email: '+email);
        try{
            AA_Customer__c customer = [SELECT Id, Name, Email__c FROM AA_Customer__c WHERE Id = :customerId];
            customer.Name = fullName;
            customer.Email__c = email;
            update customer;
            logger.info('customer updated, customerId '+customerId+ ' fullName: '+fullName+' email: '+email);
            return customer;
        }catch(Exception e){
            logger.error('error updating customer: '+e.getMessage()+' '+e.getStackTraceString());
            //throw e;
            return null;
        }
        
    }
    
    private static AA_Business__c getBusiness(){
        String businessPhoneId = '1036897699507386';
        List<AA_Business__c> businesses = [SELECT Id FROM AA_Business__c 
                                           WHERE Business_Phone_Id__c = :businessPhoneId
                                           LIMIT 1];
        if(businesses.isEmpty()){
            throw new HandledException('business not found by phone number id '+businessPhoneId);
        }
        return businesses.get(0);
    }
    
    private static AA_Business_Branch__c getBusinessBranch(Id businessId){
        List<AA_Business_Branch__c> branches = [SELECT Id FROM AA_Business_Branch__c 
                                                WHERE Business__c = :businessId
                                                ORDER BY CreatedDate DESC
                                                LIMIT 1];
        
        // TODO assuming for now that there is only one branch
        return branches.get(0);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<AA_Service_Category__c> getCategories() {
        AA_Logger logger = new AA_Logger(true);
        logger.info('getCategories, branch id '+BRANCH_ID);
        List<AA_Service_Category__c> categories = [
            SELECT Id, Name, Description_Short__c 
            FROM AA_Service_Category__c 
            WHERE Business_Branch__c = :BRANCH_ID
            // Sugerencia: podrías agregar un campo 'Order__c' para controlar la posición
            ORDER BY Name ASC 
            LIMIT 100
        ];
        logger.info('categories: '+JSON.serializePretty(categories));
        
        return categories;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<AA_Service__c> getServices() {
        AA_Logger logger = new AA_Logger(true);
        logger.info('getServices, branch id '+BRANCH_ID);
        List<AA_Service__c>  services =  [SELECT Id, Name, Duration_Minutes__c, Price__c, AA_Service_Category__c
                                          FROM AA_Service__c 
                                          WHERE Business_Branch__c = :BRANCH_ID
                                          LIMIT 100];
        
        logger.info('services: '+JSON.serializePretty(services));
        
        return services;
    }
    
}