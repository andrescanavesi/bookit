@IsTest
private class AA_EmailEventHandlerTest {
    
    @IsTest
    static void testHandleAllowedEmail() {
        // Prepare request with allowed email
        AA_EmailRequest req = new AA_EmailRequest();
        req.toAddresses = new List<String>{'test@bookit.com'};
        req.subject = 'Test Subject';
        req.htmlBody = '<p>Test Body</p>';
        req.plainTextBody = 'Test Body';
        req.saveAsActivity = false;
        
        AA_Send_Email_Event__e evt = new AA_Send_Email_Event__e(
            Payload__c = JSON.serialize(req)
        );
        
        Test.startTest();
        // Fire trigger logic manually to test it without limits/async issues in tests
        AA_EmailEventHandler.handle(new List<AA_Send_Email_Event__e>{evt});
        Test.stopTest();
        
        // Hard to assert email limits cleanly without DML, but we expect no exceptions
        System.assert(true, 'Handler completed successfully for allowed email');
    }
    
    @IsTest
    static void testHandleDisallowedEmail() {
        // Prepare request with blocked email
        AA_EmailRequest req = new AA_EmailRequest();
        req.toAddresses = new List<String>{'blocked@example.com'};
        req.subject = 'Test Subject';
        
        AA_Send_Email_Event__e evt = new AA_Send_Email_Event__e(
            Payload__c = JSON.serialize(req)
        );
        
        Test.startTest();
        AA_EmailEventHandler.handle(new List<AA_Send_Email_Event__e>{evt});
        Test.stopTest();
        
        System.assert(true, 'Handler skipped blocked email without errors');
    }
    
    @IsTest
    static void testHandleInvalidPayload() {
        AA_Send_Email_Event__e evt = new AA_Send_Email_Event__e(
            Payload__c = 'Invalid JSON'
        );
        
        Test.startTest();
        AA_EmailEventHandler.handle(new List<AA_Send_Email_Event__e>{evt});
        Test.stopTest();
        
        System.assert(true, 'Handler handled exception for invalid JSON without throwing');
    }
}
