import { Router, type Request, type Response } from 'express';

export const redirectRouter = Router();

redirectRouter.get('/:code', (_req: Request, res: Response) => {
    const { code } = _req.params;
    res.redirect(302, `https://www.google.com/${code}`);
});