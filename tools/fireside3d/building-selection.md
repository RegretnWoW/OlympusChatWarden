# Camp shelter selection

**Furbolg forest tent — FileDataID 202016 — native M2**

`world/kalimdor/kalidar/passivedoodads/furbolgtent/furbolgtent.m2`

Identity source: the existing [wowdev verified listfile](https://github.com/wowdev/wow-listfile). The user rendered and accepted this exact asset in Forever, so its catalog status is **USER_REPORTED_NATIVE_RENDER**. Candidate 10 retains it as the one default shelter. Its camp arrangement was subsequently accepted by the user with candidate 8. No scene asset or placement changes are made in candidate 10.

The previous Night Elf tent, **328178**, is also user-reported working and remains in the existing editor catalog. It is not placed in the camp.

The four older Elwynn WMO entries remain manually available, labeled **ELWYNN_WMO_RENDER_UNVERIFIED**. They are not part of startup. No additional asset research, unknown model requests, model scanner or converted MDX is introduced.

The existing editor's **Add forest tent** action still adds another 202016 only when clicked, using the existing AddObject/native M2 loader with a 3.2-unit preview height and decoration collision. It is optional; the default camp shelter is already present. No automatic retries or spawn loops are added.
