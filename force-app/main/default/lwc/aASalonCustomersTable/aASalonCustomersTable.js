import { LightningElement, track } from 'lwc';

export default class AASalonCustomersTable extends LightningElement {
    
    @track customers = [];

    connectedCallback() {
        this.initCustomers();
    }

    initCustomers() {
        // Datos simulados con la estructura solicitada
        const customerList = [
            { id: 'C1', firstName: 'Lucía', lastName: 'Pérez', phone: '+598 99 123 456', email: 'lucia.perez@mail.com', comments: 'Prefiere café cortado sin azúcar. Tono de reflejos rubio frío siempre.', baseColor: '#B23A3A' },
            { id: 'C2', firstName: 'María', lastName: 'González', phone: '+598 98 765 432', email: 'maria.g@mail.com', comments: 'Suele reagendar los viernes por la tarde. Sensibilidad a ciertos champús.', baseColor: '#D4A017' },
            { id: 'C3', firstName: 'Ana', lastName: 'Silva', phone: '+598 94 111 222', email: 'ana.silva@mail.com', comments: 'Corte específico texturizado en capas cortas. Muy puntual.', baseColor: '#3A70A1' },
            { id: 'C4', firstName: 'Carla', lastName: 'Torres', phone: '#598 93 444 555', email: 'carla.t@mail.com', comments: 'Cliente frecuente de manicura semipermanente. Le gustan los tonos nude.', baseColor: '#5A8A4F' },
            { id: 'C5', firstName: 'Valeria', lastName: 'Cáceres', phone: '+598 95 888 999', email: 'valeria@mail.com', comments: 'Realiza tratamiento de hidratación profunda cada 20 días.', baseColor: '#A15C3A' }
        ];

        // Procesamos para inyectar los estilos premium de los avatares
        this.customers = customerList.map(cust => {
            const initial = cust.firstName.substring(0, 1).toUpperCase();
            return {
                ...cust,
                initial: initial,
                avatarStyle: `background-color: ${cust.baseColor}12; color: ${cust.baseColor}; border: 1px solid ${cust.baseColor}25;`
            };
        });
    }
}