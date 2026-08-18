const tabs = document.querySelectorAll("#tabs .tab");
const panels = { doctors: document.getElementById("panel-doctors"), teams: document.getElementById("panel-teams"), hospitals: document.getElementById("panel-hospitals") };

tabs.forEach((btn) => {
  btn.addEventListener("click", () => {
    const key = btn.dataset.t;
    tabs.forEach((b) => b.classList.toggle("active", b === btn));
    Object.entries(panels).forEach(([k, el]) => el.classList.toggle("hidden", k !== key));
  });
});
