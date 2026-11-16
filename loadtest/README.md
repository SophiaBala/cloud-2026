# Навантажувальний тест

Основний сценарій (1 запис і 9 читань, фази 3 + 5 + 2 хв):

```bash
./loadtest/run.sh <мітка>
VUS=45 ./loadtest/run.sh n45
```

Сценарій для черги (лише записи через `POST /shop/async`):

```bash
SCRIPT=queue.js RATE=15 ./loadtest/run.sh queue
```

Адреса береться з `terraform output app_url`, або її можна задати через `BASE_URL`. Потрібен k6 або Docker. Результати зберігаються в `loadtest/results/`.

Детальніше — у `docs/LOADTEST.md` і `docs/QUEUE.md`.
