import { LightningElement, track, wire } from 'lwc';
import getEmployees from '@salesforce/apex/AA_SalonAppointmentsController.getEmployees';

export default class AASalonEmployeesTable extends LightningElement {
    
    @track employees = [];

    connectedCallback() {
        this.initEmployees();
    }

    async initEmployees() {
        try {
            const result = await getEmployees();
            
            // Array de colores para asignar dinámicamente si es necesario
            const colores = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#6B4F8E', '#A15C3A'];
            
            this.employees = result.map((emp, index) => {
                const fName = emp.First_Name__c || '';
                const lName = emp.Last_Name__c || '';
                const fullName = (fName + ' ' + lName).trim() || emp.Name;
                const branchName = emp.Business_Branch__r ? emp.Business_Branch__r.Name : 'Sin sucursal';
                
                // Iniciales
                const initials = fullName.substring(0, 2).toUpperCase();
                
                // Color cíclico
                const color = colores[index % colores.length];

                return {
                    id: emp.Id,
                    name: fullName,
                    role: emp.Is_Admin__c ? 'Administrador' : 'Staff',
                    branch: branchName,
                    status: 'Activo', // Asumido por defecto
                    initials: initials,
                    statusClass: 'badge badge--active',
                    permRole: emp.Is_Admin__c ? 'Administrador' : 'Staff',
                    dotStyle: `background-color: ${color};`,
                    avatarStyle: `background-color: ${color}15; color: ${color}; border: 1px solid ${color}30;`
                };
            });
        } catch (error) {
            console.error('Error al obtener empleados:', JSON.stringify(error));
        }
    }
}