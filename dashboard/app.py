import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

st.set_page_config(
    page_title="Retail Inventory Analytics",
    layout="wide",
)

RISK_ORDER = ["Understocked", "Balanced", "High Inventory", "Excess Inventory"]
RISK_COLORS = {
    "Understocked": "#EF553B",
    "Balanced": "#00CC96",
    "High Inventory": "#FFA15A",
    "Excess Inventory": "#636EFA",
}
SEGMENT_COLORS = {
    "Fast-moving": "#00CC96",
    "Medium-moving": "#FFA15A",
    "Slow-moving": "#EF553B",
}

DATA_PATH = "../data/processed/retail_store_inventory_clean.csv"


# ============================================================
# Data loading & shared calculations
# ============================================================

@st.cache_data
def load_data(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["Date"])
    return df


@st.cache_data
def compute_risk_status(df: pd.DataFrame) -> pd.DataFrame:
    """4-tier inventory risk classification, consistent across the project.

    Understocked   : inventory_level < demand_forecast
    Balanced        : inventory_level <= 1.5 x demand_forecast
    High Inventory  : inventory_level <= 2.0 x demand_forecast
    Excess Inventory: inventory_level  > 2.0 x demand_forecast
    """
    out = df.copy()
    ratio = out["Inventory Level"] / out["Demand Forecast"].replace(0, pd.NA)

    conditions = [
        out["Inventory Level"] < out["Demand Forecast"],
        ratio <= 1.5,
        ratio <= 2.0,
    ]
    choices = ["Understocked", "Balanced", "High Inventory"]
    out["Risk Status"] = pd.Series(
        pd.NA, index=out.index, dtype="object"
    )
    for cond, choice in zip(conditions, choices):
        out.loc[out["Risk Status"].isna() & cond, "Risk Status"] = choice
    out["Risk Status"] = out["Risk Status"].fillna("Excess Inventory")

    return out


@st.cache_data
def compute_movement_segments(df: pd.DataFrame) -> pd.DataFrame:
    """Product-level turnover proxy and Fast/Medium/Slow-moving terciles."""
    movement = (
        df.groupby("Product ID")
        .agg(
            total_units_sold=("Units Sold", "sum"),
            avg_inventory=("Inventory Level", "mean"),
            total_days=("Units Sold", "size"),
        )
    )
    movement["inventory_turnover_proxy"] = movement["total_units_sold"] / (
        movement["avg_inventory"] * movement["total_days"]
    )
    movement["movement_segment"] = pd.qcut(
        movement["inventory_turnover_proxy"],
        q=3,
        labels=["Slow-moving", "Medium-moving", "Fast-moving"],
    )
    return movement.reset_index()


@st.cache_data
def compute_reorder_table(df: pd.DataFrame) -> pd.DataFrame:
    """Replenishment recommendation using the latest date as 'current'.

    Reorder trigger : inventory_level < demand_forecast
    Recommended qty : only computed when triggered, with a 10% buffer
                       applied to demand_forecast (documented assumption,
                       loosely motivated by observed forecast error/MAPE).
    """
    latest_date = df["Date"].max()
    snapshot = compute_risk_status(df[df["Date"] == latest_date]).copy()

    snapshot["Reorder Trigger"] = snapshot["Inventory Level"] < snapshot["Demand Forecast"]
    snapshot["Recommended Order Qty"] = 0
    triggered = snapshot["Reorder Trigger"]
    snapshot.loc[triggered, "Recommended Order Qty"] = (
        (snapshot.loc[triggered, "Demand Forecast"] * 1.10
         - snapshot.loc[triggered, "Inventory Level"])
        .round(0)
        .clip(lower=0)
        .astype(int)
    )

    return snapshot, latest_date


df = load_data(DATA_PATH)
df_risk = compute_risk_status(df)
movement = compute_movement_segments(df)
reorder_table, latest_date = compute_reorder_table(df)


# ============================================================
# Header
# ============================================================

st.title("📦 Retail Inventory Analytics")
st.caption(
    "Where are the biggest inventory inefficiencies, which products/stores "
    "are at risk, and what inventory actions should the business take?"
)
st.caption(
    "⚠️ This dashboard uses risk **indicators/proxies**, not confirmed "
    "stockouts or financial inventory turnover — no supplier, lead-time, "
    "warehouse, or cost data is available in this dataset."
)

tab1, tab2, tab3, tab4 = st.tabs(
    [
        "📊 Inventory Overview",
        "🏷️ Product Performance",
        "🏬 Store & Regional Performance",
        "🚨 Replenishment Actions",
    ]
)


# ============================================================
# Panel 1 — Inventory Overview
# ============================================================

with tab1:
    st.subheader("Inventory Overview")

    total_sold = df["Units Sold"].sum()
    total_ordered = df["Units Ordered"].sum()
    avg_inventory = df["Inventory Level"].mean()
    low_inv_risk_rate = (df_risk["Risk Status"] == "Understocked").mean() * 100
    overstock_risk_rate = (df_risk["Risk Status"] == "Excess Inventory").mean() * 100

    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Avg Inventory", f"{avg_inventory:,.0f}")
    c2.metric("Total Units Sold", f"{total_sold:,.0f}")
    c3.metric("Total Units Ordered", f"{total_ordered:,.0f}")
    c4.metric("Low-Inventory Risk Rate", f"{low_inv_risk_rate:.1f}%")
    c5.metric("Overstock Risk Rate", f"{overstock_risk_rate:.1f}%")

    col_a, col_b = st.columns(2)

    with col_a:
        st.markdown("**Monthly Units Sold vs Units Ordered**")
        monthly = (
            df.groupby(df["Date"].dt.to_period("M"))
            .agg(**{"Units Sold": ("Units Sold", "sum"),
                     "Units Ordered": ("Units Ordered", "sum")})
        )
        monthly.index = monthly.index.to_timestamp()

        fig_trend = go.Figure()
        fig_trend.add_trace(go.Scatter(
            x=monthly.index, y=monthly["Units Sold"],
            mode="lines", name="Units Sold",
            line=dict(color="#00CC96", width=3),
            fill="tozeroy", fillcolor="rgba(0,204,150,0.15)",
        ))
        fig_trend.add_trace(go.Scatter(
            x=monthly.index, y=monthly["Units Ordered"],
            mode="lines", name="Units Ordered",
            line=dict(color="#636EFA", width=2, dash="dash"),
        ))
        fig_trend.update_layout(
            margin=dict(l=10, r=10, t=10, b=10),
            legend=dict(orientation="h", yanchor="bottom", y=1.02, x=0),
            hovermode="x unified",
            height=380,
        )
        st.plotly_chart(fig_trend, use_container_width=True)

    with col_b:
        st.markdown("**Inventory Risk Distribution**")
        risk_counts = (
            df_risk["Risk Status"]
            .value_counts()
            .reindex(RISK_ORDER)
            .reset_index()
        )
        risk_counts.columns = ["Risk Status", "Observations"]

        fig_donut = px.pie(
            risk_counts, names="Risk Status", values="Observations",
            hole=0.55, color="Risk Status",
            color_discrete_map=RISK_COLORS,
        )
        fig_donut.update_traces(
            textinfo="percent+label", pull=[0.05, 0, 0, 0],
        )
        fig_donut.update_layout(
            margin=dict(l=10, r=10, t=10, b=10),
            showlegend=False,
            height=380,
        )
        st.plotly_chart(fig_donut, use_container_width=True)

    st.markdown("**Inventory Level vs Demand Forecast**")
    st.caption(
        "Sampled for readability. Points above the diagonal line have more "
        "inventory than forecasted demand; points below are understocked."
    )
    sample = df_risk.sample(n=min(4000, len(df_risk)), random_state=42)
    fig_scatter = px.scatter(
        sample, x="Demand Forecast", y="Inventory Level",
        color="Risk Status", color_discrete_map=RISK_COLORS,
        category_orders={"Risk Status": RISK_ORDER},
        opacity=0.5, height=450,
        hover_data=["Store ID", "Product ID", "Category"],
    )
    max_val = max(sample["Demand Forecast"].max(), sample["Inventory Level"].max())
    fig_scatter.add_trace(go.Scatter(
        x=[0, max_val], y=[0, max_val], mode="lines",
        line=dict(color="gray", dash="dot"), name="Inventory = Forecast",
        showlegend=True,
    ))
    fig_scatter.update_layout(margin=dict(l=10, r=10, t=10, b=10))
    st.plotly_chart(fig_scatter, use_container_width=True)


# ============================================================
# Panel 2 — Product Performance
# ============================================================

with tab2:
    st.subheader("Product Performance")

    categories = ["All"] + sorted(df["Category"].unique().tolist())
    selected_category = st.selectbox("Filter by Category", categories)

    products = ["All"] + sorted(df["Product ID"].unique().tolist())
    selected_product = st.selectbox("Filter by Product", products)

    filtered = df.copy()
    if selected_category != "All":
        filtered = filtered[filtered["Category"] == selected_category]
    if selected_product != "All":
        filtered = filtered[filtered["Product ID"] == selected_product]

    filtered_risk = compute_risk_status(filtered)

    product_view = movement.copy()
    if selected_product != "All":
        product_view = product_view[product_view["Product ID"] == selected_product]

    col_a, col_b = st.columns(2)

    with col_a:
        st.markdown("**Inventory Turnover Proxy by Product**")
        sorted_view = product_view.sort_values("inventory_turnover_proxy")
        fig_bar = px.bar(
            sorted_view, x="inventory_turnover_proxy", y="Product ID",
            color="movement_segment", orientation="h",
            color_discrete_map=SEGMENT_COLORS,
            category_orders={"movement_segment": ["Fast-moving", "Medium-moving", "Slow-moving"]},
            labels={"inventory_turnover_proxy": "Turnover Proxy", "movement_segment": "Segment"},
            height=460,
        )
        fig_bar.update_layout(margin=dict(l=10, r=10, t=10, b=10))
        st.plotly_chart(fig_bar, use_container_width=True)

    with col_b:
        st.markdown("**Fast vs Slow-Moving Products**")
        st.caption("Bubble size = total units sold. Further right = more turnover.")
        fig_bubble = px.scatter(
            product_view, x="inventory_turnover_proxy", y="avg_inventory",
            size="total_units_sold", color="movement_segment",
            color_discrete_map=SEGMENT_COLORS,
            category_orders={"movement_segment": ["Fast-moving", "Medium-moving", "Slow-moving"]},
            hover_name="Product ID", size_max=40,
            labels={"inventory_turnover_proxy": "Turnover Proxy", "avg_inventory": "Avg Inventory"},
            height=460,
        )
        fig_bubble.update_layout(margin=dict(l=10, r=10, t=10, b=10))
        st.plotly_chart(fig_bubble, use_container_width=True)

    st.markdown("**Product-Level Detail**")
    st.caption(
        "Inventory turnover proxy = units sold / average inventory "
        "(unit-based proxy, not standard accounting turnover)."
    )
    st.dataframe(
        product_view[
            ["Product ID", "total_units_sold", "avg_inventory",
             "inventory_turnover_proxy", "movement_segment"]
        ].sort_values("inventory_turnover_proxy", ascending=False),
        use_container_width=True,
    )


# ============================================================
# Panel 3 — Store & Regional Performance
# ============================================================

with tab3:
    st.subheader("Store & Regional Performance")

    store_summary = (
        df_risk.groupby("Store ID")
        .agg(
            units_sold=("Units Sold", "sum"),
            avg_inventory=("Inventory Level", "mean"),
        )
        .round(1)
    )
    store_risk_rate = (
        df_risk.groupby("Store ID")["Risk Status"]
        .apply(lambda x: (x == "Understocked").mean() * 100)
        .round(2)
    )
    store_summary["low_inventory_risk_rate_%"] = store_risk_rate

    region_summary = (
        df_risk.groupby("Region")
        .agg(
            units_sold=("Units Sold", "sum"),
            avg_inventory=("Inventory Level", "mean"),
        )
        .round(1)
    )
    region_risk_rate = (
        df_risk.groupby("Region")["Risk Status"]
        .apply(lambda x: (x == "Understocked").mean() * 100)
        .round(2)
    )
    region_summary["low_inventory_risk_rate_%"] = region_risk_rate

    col_a, col_b = st.columns(2)

    with col_a:
        st.markdown("**Low-Inventory Risk Rate by Store**")
        fig_store_risk = px.bar(
            store_summary.reset_index(), x="Store ID", y="low_inventory_risk_rate_%",
            color="low_inventory_risk_rate_%", color_continuous_scale="Reds",
            labels={"low_inventory_risk_rate_%": "Risk Rate (%)"},
            height=350,
        )
        fig_store_risk.update_layout(
            margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False
        )
        st.plotly_chart(fig_store_risk, use_container_width=True)
        st.dataframe(store_summary, use_container_width=True)

    with col_b:
        st.markdown("**Low-Inventory Risk Rate by Region**")
        fig_region_risk = px.bar(
            region_summary.reset_index(), x="Region", y="low_inventory_risk_rate_%",
            color="low_inventory_risk_rate_%", color_continuous_scale="Reds",
            labels={"low_inventory_risk_rate_%": "Risk Rate (%)"},
            height=350,
        )
        fig_region_risk.update_layout(
            margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False
        )
        st.plotly_chart(fig_region_risk, use_container_width=True)
        st.dataframe(region_summary, use_container_width=True)

    st.markdown("**Inventory Risk Composition by Store**")
    st.caption("Where each store's observations fall across the 4 risk tiers.")
    store_risk_dist = (
        df_risk.groupby(["Store ID", "Risk Status"]).size()
        .reset_index(name="Observations")
    )
    fig_stacked = px.bar(
        store_risk_dist, x="Store ID", y="Observations", color="Risk Status",
        color_discrete_map=RISK_COLORS,
        category_orders={"Risk Status": RISK_ORDER},
        height=400,
    )
    fig_stacked.update_layout(margin=dict(l=10, r=10, t=10, b=10))
    st.plotly_chart(fig_stacked, use_container_width=True)

    st.markdown("**Average Units Sold: Store × Category Heatmap**")
    heatmap_data = (
        df.groupby(["Store ID", "Category"])["Units Sold"].mean().unstack()
    )
    fig_heat = px.imshow(
        heatmap_data, text_auto=".0f", color_continuous_scale="Blues",
        aspect="auto", height=350,
        labels=dict(color="Avg Units Sold"),
    )
    fig_heat.update_layout(margin=dict(l=10, r=10, t=10, b=10))
    st.plotly_chart(fig_heat, use_container_width=True)


# ============================================================
# Panel 4 — Replenishment Actions
# ============================================================

with tab4:
    st.subheader("Replenishment Actions")
    st.caption(
        f"Snapshot date: **{latest_date.date()}** — the most recent date "
        "in the dataset, treated as 'current' inventory. Recommended order "
        "quantity applies a 10% buffer over demand forecast, only for "
        "store-product combinations that triggered a reorder."
    )

    action_table = reorder_table[reorder_table["Reorder Trigger"]][
        ["Store ID", "Product ID", "Category", "Region",
         "Inventory Level", "Demand Forecast",
         "Risk Status", "Recommended Order Qty"]
    ].sort_values("Recommended Order Qty", ascending=False)

    if action_table.empty:
        st.success("No store-product combinations currently trigger a reorder.")
    else:
        st.markdown(f"**{len(action_table)} store-product combinations need attention right now:**")

        action_table["Label"] = action_table["Store ID"] + " · " + action_table["Product ID"]
        fig_priority = px.bar(
            action_table.sort_values("Recommended Order Qty"),
            x="Recommended Order Qty", y="Label", color="Category",
            orientation="h", text="Recommended Order Qty",
            height=max(300, 40 * len(action_table)),
        )
        fig_priority.update_traces(textposition="outside")
        fig_priority.update_layout(
            margin=dict(l=10, r=10, t=10, b=10), yaxis_title="",
        )
        st.plotly_chart(fig_priority, use_container_width=True)

        st.dataframe(action_table.drop(columns="Label"), use_container_width=True)

        st.metric(
            "Total Recommended Order Quantity",
            f"{action_table['Recommended Order Qty'].sum():,.0f} units",
        )

    with st.expander("View full inventory status for all products (current snapshot)"):
        st.dataframe(
            reorder_table[
                ["Store ID", "Product ID", "Category", "Region",
                 "Inventory Level", "Demand Forecast", "Risk Status",
                 "Reorder Trigger", "Recommended Order Qty"]
            ].sort_values("Recommended Order Qty", ascending=False),
            use_container_width=True,
        )