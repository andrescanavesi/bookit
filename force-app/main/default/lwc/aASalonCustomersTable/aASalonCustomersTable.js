import { LightningElement, track, wire } from 'lwc';
import getCustomers from '@salesforce/apex/AA_SalonAppointmentsController.getCustomers';

export default class AASalonCustomersTable extends LightningElement {
    
    @track customers = [];

    connectedCallback() {
        this.initCustomers();
    }

    async initCustomers() {
        try {
            const result = await getCustomers();
            
            const colores = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#A15C3A'];
            
            this.customers = result.map((cust, index) => {
                const fName = cust.First_Name__c || '';
                const lName = cust.Last_Name__c || '';
                const fullName = (fName + ' ' + lName).trim() || cust.Name;
                const phone = cust.Phone_Number__c || '-';
                const email = cust.Email__c || '-';
                const comments = cust.Internal_Comments__c || '';
                
                const initial = fName ? fName.substring(0, 1).toUpperCase() : (fullName ? fullName.substring(0, 1).toUpperCase() : 'C');
                const baseColor = colores[index % colores.length];

                return {
                    id: cust.Id,
                    firstName: fName || cust.Name,
                    lastName: lName,
                    phone: phone,
                    email: email,
                    comments: comments,
                    initial: initial,
                    avatarStyle: `background-color: ${baseColor}12; color: ${baseColor}; border: 1px solid ${baseColor}25;`
                };
            });
        } catch (error) {
            console.error('Error al obtener clientes:', JSON.stringify(error));
        }
    }
}