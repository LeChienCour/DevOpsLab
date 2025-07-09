import React, { useEffect, useState } from 'react';

const API_URL = 'http://localhost:4000/api';

function App() {
  const [users, setUsers] = useState([]);
  const [projects, setProjects] = useState([]);
  const [tasks, setTasks] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}/users`).then(res => res.json()).then(setUsers);
    fetch(`${API_URL}/projects`).then(res => res.json()).then(setProjects);
    fetch(`${API_URL}/tasks`).then(res => res.json()).then(setTasks);
  }, []);

  return (
    <div style={{ fontFamily: 'sans-serif', padding: 20 }}>
      <h1>TaskFlow Frontend</h1>
      <h2>Users</h2>
      <ul>{users.map(u => <li key={u.id}>{u.username} ({u.email})</li>)}</ul>
      <h2>Projects</h2>
      <ul>{projects.map(p => <li key={p.id}>{p.name} - {p.status}</li>)}</ul>
      <h2>Tasks</h2>
      <ul>{tasks.map(t => <li key={t.id}>{t.title} - {t.status}</li>)}</ul>
    </div>
  );
}

export default App; 