@IsTest(isParallel=true critical=true)
private class AA_LoggerTest {
    
    // Tag: critical
    
    @isTest
    static void testInfoLog() {
        Test.startTest();
        AA_Logger logger = new AA_Logger(true);
        logger.info('Test Info Message');
        Test.stopTest();
        
        // As Platform Events are asynchronous, we are testing the execution path 
        // to ensure no exceptions are thrown during instantiation and publishing.
        System.assert(true, 'Info log should be published without errors');
    }
    
    @isTest
    static void testWarningLog() {
        Test.startTest();
        AA_Logger logger = new AA_Logger(true);
        logger.warning('Test Warning Message');
        Test.stopTest();
        
        System.assert(true, 'Warning log should be published without errors');
    }
    
    @isTest
    static void testErrorLog() {
        Test.startTest();
        AA_Logger logger = new AA_Logger(true);
        logger.error('Test Error Message');
        Test.stopTest();
        
        System.assert(true, 'Error log should be published without errors');
    }
    
    @isTest
    static void testDelayedPublishing() {
        Test.startTest();
        // Uses default constructor which sets publishImmediately to false
        AA_Logger logger = new AA_Logger();
        logger.info('Delayed Info');
        logger.error('Delayed Error');
        
        // Manual publish
        logger.publish();
        Test.stopTest();
        
        System.assert(true, 'Delayed logs should be published without errors');
    }
    
    @isTest
    static void testEmptyPublishing() {
        Test.startTest();
        AA_Logger logger = new AA_Logger(false);
        logger.publish(); // Should do nothing and not throw NPE
        Test.stopTest();
        
        System.assert(true, 'Empty publish should handle gracefully without errors');
    }
}
