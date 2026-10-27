// Server lokal untuk development: npm run dev
import app from './app.js';

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => console.log(`NaikIn API jalan di http://localhost:${port}`));
