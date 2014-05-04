import os, gpgme

def vault(sid):
    vault = os.path.join(os.environ['SIMBOL_USER_ETC'], 'simbol.vault')
    if os.path.exists(vault):
        from io import BytesIO
        o = BytesIO()
        with open(vault, 'r') as ifH:
            from gpgme import Context
            ctx = Context()
            ctx.armor = True
            ctx.decrypt(ifH, o)
        return dict(
            (_.split(None, 1) for _ in o.getvalue().split('\n') if _)
        ).get(secret, '').strip()
