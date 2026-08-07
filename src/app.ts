import express from 'express';
import { healthRouter } from './routes/health.js';
import { shortenRouter } from './routes/shorten.js';
import { redirectRouter } from './routes/redirect.js';

export const app = express();
app.use(express.json());
app.use(healthRouter);
app.use(shortenRouter);
app.use(redirectRouter);
