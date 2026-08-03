import { Router, type Request, type Response } from 'express';

export const shortenRouter = Router();

shortenRouter.get('/shorten', (_req: Request, res: Response) => {
    const { url } = _req.body.url;
    res.json({
        code: 'stubbed',
        shortUrl: 'http://localhost:3000/stubbed'
    });
});