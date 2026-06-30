public with sharing class AA_CustomerTriggerHandler {
    
    public static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return phone;
        String clean = phone.replaceAll('\\D', ''); // Quita todo lo que no sea dígito
        
        if (clean.startsWith('00')) {
            clean = clean.substring(2);
        }
        
        if (clean.startsWith('09') && clean.length() == 9) {
            clean = '598' + clean.substring(1);
        }
        
        return clean;
    }
    
    public static void handleBeforeInsertUpdate(List<AA_Customer__c> newRecords, Map<Id, AA_Customer__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        
        // --- NORMALIZACIÓN DE TELÉFONO (WhatsApp format) ---
        // Normalizamos el teléfono antes de revisar duplicados para asegurar integridad
        for (AA_Customer__c record : newRecords) {
            if (isInsert && String.isNotBlank(record.Phone_Number__c)) {
                record.Phone_Number__c = normalizePhone(record.Phone_Number__c);
            }
        }
        
        List<AA_Customer__c> recordsToProcess = new List<AA_Customer__c>();
        Set<Id> businessIds = new Set<Id>();
        
        for (AA_Customer__c record : newRecords) {
            Boolean needsUpdate = false;
            
            if (isInsert) {
                needsUpdate = true;
            } else if (isUpdate) {
                AA_Customer__c oldRecord = oldMap.get(record.Id);
                if (record.Name != oldRecord.Name || 
                    record.First_Name__c != oldRecord.First_Name__c || 
                    record.Last_Name__c != oldRecord.Last_Name__c || 
                    record.Business__c != oldRecord.Business__c) {
                    needsUpdate = true;
                }
            }
            
            if (needsUpdate && record.Business__c != null) {
                recordsToProcess.add(record);
                businessIds.add(record.Business__c);
            }
        }
        
        // --- VALIDACIÓN DE DUPLICADOS DE CELULAR ---
        Set<String> phoneNumbers = new Set<String>();
        Set<Id> phoneBusinessIds = new Set<Id>();
        
        for (AA_Customer__c record : newRecords) {
            if (String.isNotBlank(record.Phone_Number__c) && record.Business__c != null) {
                Boolean needsPhoneCheck = false;
                if (isInsert) {
                    needsPhoneCheck = true;
                } else if (isUpdate) {
                    AA_Customer__c oldRecord = oldMap.get(record.Id);
                    if (record.Phone_Number__c != oldRecord.Phone_Number__c || record.Business__c != oldRecord.Business__c) {
                        needsPhoneCheck = true;
                    }
                }
                
                if (needsPhoneCheck) {
                    phoneNumbers.add(record.Phone_Number__c);
                    phoneBusinessIds.add(record.Business__c);
                }
            }
        }
        
        if (!phoneNumbers.isEmpty() && !phoneBusinessIds.isEmpty()) {
            Map<String, Id> existingKeys = new Map<String, Id>();
            for (AA_Customer__c ec : [
                SELECT Id, Phone_Number__c, Business__c 
                FROM AA_Customer__c 
                WHERE Phone_Number__c IN :phoneNumbers 
                  AND Business__c IN :phoneBusinessIds
            ]) {
                existingKeys.put(ec.Business__c + '-' + ec.Phone_Number__c, ec.Id);
            }
            
            Set<String> inMemoryKeys = new Set<String>();
            
            for (AA_Customer__c record : newRecords) {
                if (String.isNotBlank(record.Phone_Number__c) && record.Business__c != null) {
                    Boolean needsPhoneCheck = false;
                    if (isInsert) {
                        needsPhoneCheck = true;
                    } else if (isUpdate) {
                        AA_Customer__c oldRecord = oldMap.get(record.Id);
                        if (record.Phone_Number__c != oldRecord.Phone_Number__c || record.Business__c != oldRecord.Business__c) {
                            needsPhoneCheck = true;
                        }
                    }
                    
                    if (needsPhoneCheck) {
                        String key = record.Business__c + '-' + record.Phone_Number__c;
                        
                        if (existingKeys.containsKey(key) && existingKeys.get(key) != record.Id) {
                            record.Phone_Number__c.addError('Ya existe una persona con este número de celular en tu salón.');
                        } else if (inMemoryKeys.contains(key)) {
                            record.Phone_Number__c.addError('Ya existe una persona con este número de celular en tu salón.');
                        } else {
                            inMemoryKeys.add(key);
                        }
                    }
                }
            }
        }
        // --- FIN VALIDACIÓN DE DUPLICADOS ---
        
        if (!recordsToProcess.isEmpty()) {
            Map<Id, AA_Business__c> businessMap = new Map<Id, AA_Business__c>([
                SELECT Id, Name FROM AA_Business__c WHERE Id IN :businessIds
            ]);
            
            for (AA_Customer__c record : recordsToProcess) {
                AA_Business__c business = businessMap.get(record.Business__c);
                if (business != null) {
                    String firstName = record.First_Name__c != null ? record.First_Name__c : '';
                    String lastName = record.Last_Name__c != null ? record.Last_Name__c : '';
                    
                    String newName = firstName;
                    if (String.isNotBlank(lastName)) {
                        newName += (String.isNotBlank(newName) ? ' ' : '') + lastName;
                    }
                    if (String.isNotBlank(business.Name)) {
                        newName += (String.isNotBlank(newName) ? ' - ' : '') + business.Name;
                    }
                    
                    record.Name = newName.abbreviate(75);
                }
            }
        }
    }
}