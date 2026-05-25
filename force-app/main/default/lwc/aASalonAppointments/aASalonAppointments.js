import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getSalonAppointments from '@salesforce/apex/AA_SalonAppointmentsController.getSalonAppointments';
import markReminderAsSent from '@salesforce/apex/AA_SalonAppointmentsController.markReminderAsSent';
import confirmAppointment from '@salesforce/apex/AA_SalonAppointmentsController.confirmAppointment';
import cancelAppointment from '@salesforce/apex/AA_SalonAppointmentsController.cancelAppointment'; // NUEVO

export default class AASalonAppointments extends LightningElement {
    @track allAppointments = [];
    @track isLoading = true;
    @track isAdmin = false;

    @track selectedEmployeeId = 'ALL';
    @track selectedTab = 'HOY'; 

    wiredAppointmentsResult; 
    employeeColors = ['#B23A3A', '#D4A017', '#3A70A1', '#5A8A4F', '#6B4F8E'];

    @wire(getSalonAppointments)
    wiredAppointments(result) {
        this.wiredAppointmentsResult = result; 
        const { error, data } = result;

        if (data) {
            if (!data.appointments) {
                console.warn('Estructura de datos inesperada (posible caché). Forzando recarga...');
                return; 
            }
            this.isAdmin = data.isAdmin;
            
            // Aquí solo procesamos los datos "crudos", sin lógica de interfaz (pestañas)
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
                    // Dejamos marcados los estados para usarlos fácilmente abajo
                    isCancelled: appt.Status__c === 'Cancelled',
                    isPending: appt.Status__c === 'Pending',
                    isReminderSent: isSent, 
                    waButtonLabel: isSent ? 'Reenviar Recordatorio' : 'Enviar Recordatorio', 
                    waButtonClass: isSent ? 'wa-btn wa-btn--sent' : 'wa-btn', 
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

    handleWhatsAppClick(event) {
        const apptId = event.currentTarget.dataset.id;
        markReminderAsSent({ appointmentId: apptId })
            .then(() => {
                return refreshApex(this.wiredAppointmentsResult);
            })
            .catch(error => {
                console.error('Error al guardar fecha de recordatorio:', error);
            });
    }

    handleConfirmClick(event) {
        const apptId = event.currentTarget.dataset.id;
        
        // 1. FEEDBACK INMEDIATO: Marcamos la cita actual como "en proceso de confirmación"
        this.allAppointments = this.allAppointments.map(appt => {
            if (appt.Id === apptId) {
                return { ...appt, isConfirming: true };
            }
            return appt;
        });

        // 2. Disparamos la acción en el servidor
        confirmAppointment({ appointmentId: apptId })
            .then(() => {
                return refreshApex(this.wiredAppointmentsResult);
            })
            .catch(error => {
                console.error('Error al confirmar la cita:', error);
                
                // Si hay un error, revertimos el estado de carga para que pueda reintentar
                this.allAppointments = this.allAppointments.map(appt => {
                    if (appt.Id === apptId) {
                        return { ...appt, isConfirming: false };
                    }
                    return appt;
                });
            });
    }

    handleCancelClick(event) {
        const apptId = event.currentTarget.dataset.id;
        
        // 1. Feedback UI: Marcamos la cita como "en proceso de cancelación"
        this.allAppointments = this.allAppointments.map(appt => {
            if (appt.Id === apptId) {
                return { ...appt, isCancelling: true };
            }
            return appt;
        });

        // 2. Disparamos la acción en el servidor
        cancelAppointment({ appointmentId: apptId })
            .then(() => {
                return refreshApex(this.wiredAppointmentsResult);
            })
            .catch(error => {
                console.error('Error al cancelar la cita:', error);
                // Si falla, revertimos el estado
                this.allAppointments = this.allAppointments.map(appt => {
                    if (appt.Id === apptId) {
                        return { ...appt, isCancelling: false };
                    }
                    return appt;
                });
            });
    }

    get employeePills() {
        const pills = [];
        const seen = new Set();
        let colorIndex = 0;
        pills.push({ id: 'ALL', label: 'Todo el equipo', isAll: true, cssClass: this.selectedEmployeeId === 'ALL' ? 'prof-pill prof-pill--active' : 'prof-pill' });
        this.allAppointments.forEach(appt => {
            if (appt.employeeId && !seen.has(appt.employeeId)) {
                seen.add(appt.employeeId);
                const color = this.employeeColors[colorIndex % this.employeeColors.length];
                colorIndex++;
                pills.push({ id: appt.employeeId, label: appt.employeeName, color: color, isAll: false, style: `background-color: ${color};`, cssClass: this.selectedEmployeeId === appt.employeeId ? 'prof-pill prof-pill--active' : 'prof-pill' });
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
            if (this.selectedTab === 'CANCELADOS') return appt.isCancelled;
            if (this.selectedTab === 'HOY') return !appt.isCancelled && apptDate.getTime() === hoy.getTime();
            if (this.selectedTab === 'MANANA') return !appt.isCancelled && apptDate.getTime() === manana.getTime();
            if (this.selectedTab === 'PROXIMOS') return !appt.isCancelled && apptDate.getTime() > manana.getTime();
            return false;
        });

        if (filtered.length === 0) return [];

        const groups = {};
        filtered.forEach(appt => {
            if (!groups[appt.fechaHeader]) groups[appt.fechaHeader] = [];
            
            const statusLabel = appt.isCancelled ? 'CANCELADO' : (appt.isPending ? 'PENDIENTE' : 'CONFIRMADO');
            const statusClass = appt.isCancelled ? 'status-label status-label--cancelled' : (appt.isPending ? 'status-label status-label--pending' : 'status-label status-label--confirmed');
            
            const empPill = this.employeePills.find(p => p.id === appt.employeeId);
            const borderColor = empPill && empPill.color ? empPill.color : '#333';

            // --- LÓGICA DE VISIBILIDAD DE BOTONES ---
            
            // 1. WhatsApp: Solo en Mañana
            const showWa = (this.selectedTab === 'MANANA' && !appt.isCancelled && !!appt.waLink);
            
            // 2. Confirmar: Solo si está Pendiente
            const showConfirm = (appt.isPending && !appt.isCancelled);
            
            // 3. Cancelar: Siempre disponible si no está cancelada ya
            const showCancel = !appt.isCancelled; 

            groups[appt.fechaHeader].push({
                ...appt,
                statusLabel: statusLabel,
                statusClass: statusClass,
                cardStyle: `border-left: 4px solid ${borderColor};`,
                showWaButton: showWa,
                showConfirmButton: showConfirm,
                showCancelButton: showCancel,
                // CLAVE: El footer se muestra si CUALQUIERA de los 3 botones debe estar visible
                hasFooterActions: showWa || showConfirm || showCancel 
            });
        });

        return Object.keys(groups).map(dateStr => { return { dateHeader: dateStr, appointments: groups[dateStr] }; });
    }

    get hasData() { return this.groupedAppointments.length > 0; }
    handleEmployeeSelect(event) { this.selectedEmployeeId = event.currentTarget.dataset.id; }
    handleTabSelect(event) { this.selectedTab = event.currentTarget.dataset.id; }  
}