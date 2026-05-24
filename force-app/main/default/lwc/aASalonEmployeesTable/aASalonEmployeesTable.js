import { LightningElement, track } from 'lwc';

export default class AASalonEmployeesTable extends LightningElement {
    
    @track employees = [];

    connectedCallback() {
        this.initEmployees();
    }

    initEmployees() {
        // Datos simulados alineados con el equipo real y su paleta de colores
        const team = [
            { id: 'E1', name: 'Silvina', role: 'Estilista Principal', branch: 'Punta Carretas', isAdmin: true, status: 'Activo', color: '#B23A3A' },
            { id: 'E2', name: 'Dahiana', role: 'Colorista Senior', branch: 'Punta Carretas', isAdmin: false, status: 'Activo', color: '#D4A017' },
            { id: 'E3', name: 'Sophie', role: 'Especialista en Peinados', branch: 'Carrasco', isAdmin: false, status: 'En Descanso', color: '#3A70A1' },
            { id: 'E4', name: 'Yamila', role: 'Estilista & Makeup', branch: 'Carrasco', isAdmin: false, status: 'Activo', color: '#5A8A4F' },
            { id: 'E5', name: 'Soledad', role: 'Manicura Profesional', branch: 'Punta Carretas', isAdmin: false, status: 'Inactivo', color: '#6B4F8E' },
            { id: 'E6', name: 'Agustina', role: 'Tratamientos Capilares', branch: 'Carrasco', isAdmin: false, status: 'Activo', color: '#A15C3A' }
        ];

        // Mapeamos los datos para inyectar elementos visuales limpios
        this.employees = team.map(emp => {
            // Generamos iniciales (ej: Silvina -> SI, Sophie -> SO)
            const initials = emp.name.substring(0, 2).toUpperCase();
            
            // Asignamos clases de CSS para los badges según el estado
            let statusClass = 'badge ';
            if (emp.status === 'Activo') statusClass += 'badge--active';
            else if (emp.status === 'En Descanso') statusClass += 'badge--away';
            else statusClass += 'badge--inactive';

            return {
                ...emp,
                initials: initials,
                statusClass: statusClass,
                permRole: emp.isAdmin ? 'Administrador' : 'Staff',
                dotStyle: `background-color: ${emp.color};`,
                avatarStyle: `background-color: ${emp.color}15; color: ${emp.color}; border: 1px solid ${emp.color}30;`
            };
        });
    }
}