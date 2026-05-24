import { LightningElement, wire, track } from 'lwc';
import getSalonAppointments from '@salesforce/apex/AA_SalonAppointmentsController.getSalonAppointments';


export default class AASalonAppointments extends LightningElement {
    
    @track isAdmin = false;
    
    // Estado de las pestañas
    @track activeTab = 'hoy'; 

    // Listas filtradas
    @track hoyAppointments = [];
    @track mananaAppointments = [];
    @track proximosAppointments = [];

    // Getter para las clases CSS de las pestañas
    get tabHoyClass() { return this.activeTab === 'hoy' ? 'tab active-tab' : 'tab'; }
    get tabMananaClass() { return this.activeTab === 'manana' ? 'tab active-tab' : 'tab'; }
    get tabProximosClass() { return this.activeTab === 'proximos' ? 'tab active-tab' : 'tab'; }

    // Getters para renderizar las vistas
    get isHoy() { return this.activeTab === 'hoy'; }
    get isManana() { return this.activeTab === 'manana'; }
    get isProximos() { return this.activeTab === 'proximos'; }

    // Métodos para cambiar de pestaña
    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    @wire(getSalonAppointments)
    wiredAppointments({ error, data }) {
        console.info('loading appointments...')
        if (data) {
            if (!data.appointments) return;
             console.info(JSON.stringify(data, null, 2));
            if (!data.appointments) {
                console.warn('Estructura de datos inesperada (posible caché). Forzando recarga...');
                return; 
            }

            this.isAdmin = data.isAdmin;

            // Fechas de referencia a las 00:00 para comparar correctamente
            const today = new Date();
            today.setHours(0, 0, 0, 0);

            const tomorrow = new Date(today);
            tomorrow.setDate(tomorrow.getDate() + 1);

            // Limpiamos las listas antes de procesar
            this.hoyAppointments = [];
            this.mananaAppointments = [];
            this.proximosAppointments = [];

            data.appointments.forEach(appt => {
                // Formateamos la hora para la tarjeta y el mensaje
                const dt = new Date(appt.Start_Date_Time__c);
                const timeString = dt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

                // Clonamos el objeto para agregarle propiedades útiles para la UI
                let apptItem = {
                    ...appt,
                    formattedTime: timeString,
                    customerName: `${appt.Customer__r.First_Name__c} ${appt.Customer__r.Last_Name__c}`,
                    serviceName: appt.Service__r.Name,
                    employeeName: appt.Employee__r.Name
                };

                // Comparamos las fechas
                const apptDate = new Date(dt);
                apptDate.setHours(0, 0, 0, 0);

                if (apptDate.getTime() === today.getTime()) {
                    this.hoyAppointments.push(apptItem);
                } 
                else if (apptDate.getTime() === tomorrow.getTime()) {
                    // Solo a los turnos de mañana les generamos el link de WhatsApp
                    apptItem.waLink = this.generateWhatsAppLink(apptItem);
                    this.mananaAppointments.push(apptItem);
                } 
                else if (apptDate.getTime() > tomorrow.getTime()) {
                    this.proximosAppointments.push(apptItem);
                }
            });
        } else if (error) {
            console.error('Error fetching appointments', error);
        }
    }

    generateWhatsAppLink(appt) {
        // Validamos que el cliente tenga número de teléfono
        if (!appt.Customer__r || !appt.Customer__r.Phone_Number__c) return null;

        // Limpiamos el número: quitamos espacios, guiones y el '+'
        // WhatsApp web requiere que sea solo números (ej: 59899123456)
        const cleanPhone = appt.Customer__r.Phone_Number__c.replace(/\D/g, '');

        // Preparamos el mensaje y lo codificamos para URL
        const text = `Hola ${appt.Customer__r.First_Name__c}, te escribimos del salón para recordarte tu turno de ${appt.serviceName} mañana a las ${appt.formattedTime} hs. ¿Nos confirmas tu asistencia?`;
        const encodedText = encodeURIComponent(text);

        return `https://wa.me/${cleanPhone}?text=${encodedText}`;
    }
}