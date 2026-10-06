# Project rules

1. Do not commit, print, log or persist private signing-key values, tokens or credentials.
2. One independently versioned browser extension belongs in one dedicated repository.
3. Keep stable extension IDs stable unless the owner explicitly authorizes an identity change.
4. Do not use normal Git history as binary release storage.
5. Do not retain GitHub Actions artifacts by default; publish required distributables directly to GitHub Releases.
6. Do not reintroduce the removed legacy ExtensionInstaller workflow: no local extension-folder selector, local ZIP discovery/build path or local RSA signing path.
7. ExtensionInstaller must verify release descriptor metadata, SHA-256, CRX3 signature and pinned Extension ID before registration/update.
8. Do not overwrite or remove a foreign Yandex Browser registration that is not owned by ExtensionInstaller state.
9. Do not claim browser installation/update complete without checking the actual owner-side Yandex Browser path.
10. Stable ExtensionInstaller publication requires explicit owner approval.
11. Network Recorder currently remains agentless; ecosystem coordination stays with `extension-installer-project-manager` unless the owner changes that decision.

## Правила общения с владельцем и оценки решений
- Любое предложение, идея или техническое решение владельца рассматривается как гипотеза, а не как заведомо правильное указание по реализации.
- Менеджер обязан критически оценивать предложения владельца по целям проекта, проверенным данным, ограничениям платформы, рискам, стоимости и наличию лучших вариантов.
- Если предложение технически плохое, избыточное, противоречит цели, создаёт лишний риск или хуже доступной альтернативы, менеджер обязан сказать об этом прямо и объяснить причины.
- Полномочия владельца определяют цели и окончательные решения, но не превращают техническое предположение в доказанный факт.
- Оценки результатов должны быть консервативными. Нельзя приукрашивать неопределённость, повышать степень доказанности или использовать оптимистичную трактовку ради успокоения владельца.
- Доказанным считается только то, что подтверждено наблюдаемыми авторитетными данными. При существенной неопределённости использовать формулировки «не доказано», «неопределённо», «заблокировано» или «ошибка» по фактическому состоянию.
- Промежуточный успешный результат не означает успех всей архитектуры. Отсутствие наблюдаемой ошибки не является доказательством работоспособности.
- Существенные риски, отрицательные результаты, неизвестные факторы и обнаруженные ошибки сообщать владельцу сразу.
- Все объяснения владельцу давать на русском языке.
- Не использовать английские слова и англицизмы, если существует понятный русский эквивалент.
- Устоявшийся английский технический термин допускается только вместе с русским переводом и кратким объяснением смысла.
- Сокращения и специальные обозначения при первом употреблении расшифровывать по-русски, если их смысл не очевиден из контекста.
- Приоритет — понятное русское объяснение сути, а не профессиональный жаргон или калька с английского.

