import { LightningElement, track, wire } from 'lwc';
import getSalonAppointments from '@salesforce/apex/AA_SalonAppointmentsController.getSalonAppointments';

export default class AA_CitasSalon extends LightningElement {
   @track allAppointments = [];      // Lista maestra original
    @track filteredAppointments = []; // Lista filtrada que se muestra en el HTML
    @track isLoading = true;

    // Estado de los filtros
    selectedEmployee = 'All';
    selectedStatus = 'All';
    selectedDate = '';

    // Opciones fijas para el filtro de estados
    statusOptions = [
        { label: 'Todos', value: 'All' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Done', value: 'Done' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    @wire(getSalonAppointments)
    wiredAppointments({ error, data }) {
        if (data) {
            this.allAppointments = data.map(appt => {
                const dt = new Date(appt.Start_Date_Time__c);
                
                const formattedDateTime = dt.toLocaleString('es-UY', {
                    day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit'
                }) + ' Hs';

                // Extraemos la fecha en formato YYYY-MM-DD para comparar con el input de tipo date
                const dateString = dt.toISOString().split('T')[0];

                const firstName = appt.Customer__r?.First_Name__c || '';
                const lastName = appt.Customer__r?.Last_Name__c || '';

                // Asignación de clases dinámicas para los badges según el estado
                let badgeClass = 'slds-badge ';
                if (appt.Status__c === 'Pending') badgeClass += 'slds-theme_warning';
                else if (appt.Status__c === 'Cancelled') badgeClass += 'slds-theme_error';
                else if (appt.Status__c === 'Done') badgeClass += 'slds-theme_success';

                return {
                    ...appt,
                    formattedDateTime: formattedDateTime,
                    dateString: dateString,
                    customerName: `${firstName} ${lastName}`.trim() || 'Cliente Sin Nombre',
                    serviceName: appt.Service__r?.Name || 'N/A',
                    employeeName: appt.Employee__r?.Name || 'N/A',
                    employeeId: appt.Employee__c,
                    statusClass: badgeClass
                };
            });
            
            this.filterData();
            this.isLoading = false;
        } else if (error) {
            console.error('Error invocando getSalonAppointments:', JSON.stringify(error));
            this.isLoading = false;
        }
    }

    // Genera dinámicamente la lista de empleados únicos presentes en las citas
    get employeeOptions() {
        const options = [{ label: 'Todos', value: 'All' }];
        const seenEmployees = new Set();

        this.allAppointments.forEach(appt => {
            if (appt.employeeId && !seenEmployees.has(appt.employeeId)) {
                seenEmployees.add(appt.employeeId);
                options.push({ label: appt.employeeName, value: appt.employeeId });
            }
        });

        return options;
    }

    // Escuchadores de cambios en los filtros
    handleEmployeeChange(event) {
        this.selectedEmployee = event.detail.value;
        this.filterData();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.filterData();
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value; // Formato YYYY-MM-DD
        this.filterData();
    }

    // Lógica combinada de filtrado
    filterData() {
        this.filteredAppointments = this.allAppointments.filter(appt => {
            const matchEmployee = this.selectedEmployee === 'All' || appt.employeeId === this.selectedEmployee;
            const matchStatus = this.selectedStatus === 'All' || appt.Status__c === this.selectedStatus;
            const matchDate = !this.selectedDate || appt.dateString === this.selectedDate;
            
            return matchEmployee && matchStatus && matchDate;
        });
    }

    get hasAppointments() {
        return this.filteredAppointments && this.filteredAppointments.length > 0;
    }
}