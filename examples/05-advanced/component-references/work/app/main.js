// Main Application v2.0.0
// This app depends on the utils library component

import { formatDate, validateEmail, capitalize } from '@acme/utils';

class UserManager {
    constructor() {
        this.users = [];
    }
    
    addUser(email, name, birthDate) {
        if (!validateEmail(email)) {
            throw new Error('Invalid email format');
        }
        
        const user = {
            email,
            name: capitalize(name),
            birthDate: formatDate(new Date(birthDate)),
            registeredAt: formatDate(new Date())
        };
        
        this.users.push(user);
        return user;
    }
    
    getUsers() {
        return this.users;
    }
}

// Example usage
const manager = new UserManager();
manager.addUser('john.doe@example.com', 'john doe', '1990-05-15');
console.log('Users:', manager.getUsers());
