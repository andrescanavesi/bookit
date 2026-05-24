import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex'; // NUEVO: Para refrescar la UI en tiempo real
import getSalonAppointments from '@salesforce/apex/AA_SalonAppointmentsController.getSalonAppointments';
import markReminderAsSent from '@salesforce/apex/AA_SalonAppointmentsController.markReminderAsSent'; // NUEVO: El método que acabamos de crear

export default class AASalonAppointments extends LightningElement {
    @track allAppointments = [];
    @track isLoading = true;
    @track isAdmin = false;

    // Filtros activos
    @track selectedEmployeeId = 'ALL';
    @track selectedTab = 'HOY'; 

    // Almacenamos el resultado del wire para poder usar refreshApex más adelante
    wiredAppointmentsResult; 

    employeeColors = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#6B4F8E'];

    @wire(getSalonAppointments)
    wiredAppointments(result) {
        this.wiredAppointmentsResult = result; // Guardamos la referencia completa
        const { error, data } = result;

        if (data) {
            if (!data.appointments) {
                console.warn('Estructura de datos inesperada (posible caché). Forzando recarga...');
                return; 
            }
            this.isAdmin = data.isAdmin;
            this.allAppointments = data.appointments.map(appt => {
                const dt = new Date(appt.Start_Date_Time__c);
                
                const DOW = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
                const MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre'];
                
                const fechaHeader = `${DOW[dt.getDay()]} ${dt.getDate()} De ${MESES[dt.getMonth()]}`;
                const horaStr = dt.toLocaleTimeString('es-UY', { hour: '2-digit', minute: '2-digit' });
                
                const firstName = appt.Customer__r?.First_Name__c || '';
                const lastName = appt.Customer__r?.Last_Name__c || '';
                const phone = appt.Customer__r?.Phone_Number__c || '';
                const serviceName = appt.Service__r?.Name || 'Servicio';
                
                // NUEVO: Validamos si ya fue enviado analizando si el campo Date/Time tiene valor
                const isSent = !!appt.Reminder_Sent_Date__c;

                return {
                    ...appt,
                    fechaRaw: dt,
                    fechaHeader: fechaHeader,
                    horaStr: horaStr,
                    customerName: `${firstName} ${lastName}`.trim() || 'Sin Nombre',
                    phone: phone || 'Sin teléfono',
                    serviceName: serviceName,
                    duration: appt.Service__r?.Duration_Minutes__c || 30,
                    employeeName: appt.Employee__r?.Name || 'Equipo',
                    employeeId: appt.Employee__c,
                    isCancelled: appt.Status__c === 'Cancelled',
                    isReminderSent: isSent, // Guardamos el booleano para el HTML
                    waButtonLabel: isSent ? 'Reenviar Recordatorio' : 'Confirmar Asistencia', // Texto dinámico
                    waButtonClass: isSent ? 'wa-btn wa-btn--sent' : 'wa-btn', // Estilo dinámico
                    waLink: this.generateWhatsAppLink(phone, firstName, serviceName, horaStr)
                };
            });
            this.isLoading = false;
        } else if (error) {
            console.error('Error cargando citas:', JSON.stringify(error));
            this.isLoading = false;
        }
    }

    generateWhatsAppLink(phone, firstName, serviceName, timeStr) {
        if (!phone) return null;
        const cleanPhone = phone.replace(/\D/g, '');
        if (!cleanPhone) return null;

        const text = `Hola ${firstName}, te escribimos del salón para recordarte tu turno de ${serviceName} mañana a las ${timeStr} hs. ¿Nos confirmas tu asistencia?`;
        return `https://wa.me/${cleanPhone}?text=${encodeURIComponent(text)}`;
    }

    // NUEVO: Evento al hacer clic en el botón de WhatsApp
    handleWhatsAppClick(event) {
        const apptId = event.currentTarget.dataset.id;

        // Ejecutamos el método de Apex imperativamente para sellar la fecha por detrás
        markReminderAsSent({ appointmentId: apptId })
            .then(() => {
                // Forzamos al componente a limpiar caché y traer los datos frescos, cambiando el botón al estado "Enviado"
                return refreshApex(this.wiredAppointmentsResult);
            })
            .catch(error => {
                console.error('Error al guardar fecha de recordatorio:', error);
            });
    }

    get employeePills() {
        const pills = [];
        const seen = new Set();
        let colorIndex = 0;

        pills.push({
            id: 'ALL',
            label: 'Todo el equipo',
            isAll: true,
            cssClass: this.selectedEmployeeId === 'ALL' ? 'prof-pill prof-pill--active' : 'prof-pill'
        });

        this.allAppointments.forEach(appt => {
            if (appt.employeeId && !seen.has(appt.employeeId)) {
                seen.add(appt.employeeId);
                const color = this.employeeColors[colorIndex % this.employeeColors.length];
                colorIndex++;
                
                pills.push({
                    id: appt.employeeId,
                    label: appt.employeeName,
                    color: color,
                    isAll: false,
                    style: `background-color: ${color};`,
                    cssClass: this.selectedEmployeeId === appt.employeeId ? 'prof-pill prof-pill--active' : 'prof-pill'
                });
            }
        });
        return pills;
    }

    get tabs() {
        return [
            { id: 'HOY', label: 'Hoy', cssClass: this.selectedTab === 'HOY' ? 'admin-tab admin-tab--active' : 'admin-tab' },
            { id: 'MANANA', label: 'Mañana', cssClass: this.selectedTab === 'MANANA' ? 'admin-tab admin-tab--active' : 'admin-tab' },
            { id: 'PROXIMOS', label: 'Próximos', cssClass: this.selectedTab === 'PROXIMOS' ? 'admin-tab admin-tab--active' : 'admin-tab' },
            { id: 'CANCELADOS', label: 'Cancelados', cssClass: this.selectedTab === 'CANCELADOS' ? 'admin-tab admin-tab--active' : 'admin-tab' }
        ];
    }

    get groupedAppointments() {
        if (!this.allAppointments || this.allAppointments.length === 0) return [];

        const hoy = new Date();
        hoy.setHours(0, 0, 0, 0);

        const manana = new Date(hoy);
        manana.setDate(manana.getDate() + 1);

        const filtered = this.allAppointments.filter(appt => {
            if (this.selectedEmployeeId !== 'ALL' && appt.employeeId !== this.selectedEmployeeId) return false;

            const apptDate = new Date(appt.fechaRaw);
            apptDate.setHours(0, 0, 0, 0);

            if (this.selectedTab === 'CANCELADOS') {
                return appt.isCancelled;
            } else if (this.selectedTab === 'HOY') {
                return !appt.isCancelled && apptDate.getTime() === hoy.getTime();
            } else if (this.selectedTab === 'MANANA') {
                return !appt.isCancelled && apptDate.getTime() === manana.getTime();
            } else if (this.selectedTab === 'PROXIMOS') {
                return !appt.isCancelled && apptDate.getTime() > manana.getTime();
            }
            return false;
        });

        if (filtered.length === 0) return [];

        const groups = {};
        filtered.forEach(appt => {
            if (!groups[appt.fechaHeader]) {
                groups[appt.fechaHeader] = [];
            }
            
            const statusLabel = appt.isCancelled ? 'CANCELADO' : (appt.Status__c === 'Pending' ? 'PENDIENTE' : 'CONFIRMADO');
            const statusClass = appt.isCancelled ? 'status-label status-label--cancelled' : 'status-label status-label--pending';
            
            const empPill = this.employeePills.find(p => p.id === appt.employeeId);
            const borderColor = empPill && empPill.color ? empPill.color : '#333';

            groups[appt.fechaHeader].push({
                ...appt,
                statusLabel: statusLabel,
                statusClass: statusClass,
                cardStyle: `border-left: 4px solid ${borderColor};`,
                showWaButton: this.selectedTab === 'MANANA' && !!appt.waLink
            });
        });

        return Object.keys(groups).map(dateStr => {
            return {
                dateHeader: dateStr,
                appointments: groups[dateStr]
            };
        });
    }

    get hasData() {
        return this.groupedAppointments.length > 0;
    }

    handleEmployeeSelect(event) {
        this.selectedEmployeeId = event.currentTarget.dataset.id;
    }

    handleTabSelect(event) {
        this.selectedTab = event.currentTarget.dataset.id;
    }  
}