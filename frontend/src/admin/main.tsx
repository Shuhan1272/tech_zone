import { createRoot } from 'react-dom/client';
import { Console } from './Console';
import './style.css';

const root = document.getElementById('admin-root');
if (!root) throw new Error('TechZone admin root element is missing.');

createRoot(root).render(<Console />);
