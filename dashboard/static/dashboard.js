const searchInput = document.getElementById("nodeSearch");
const table = document.getElementById("nodesTable");

if (searchInput && table) {
  searchInput.addEventListener("input", () => {
    const value = searchInput.value.toLowerCase();
    const rows = table.querySelectorAll("tbody tr");

    rows.forEach((row) => {
      const text = row.innerText.toLowerCase();
      row.style.display = text.includes(value) ? "" : "none";
    });
  });
}
